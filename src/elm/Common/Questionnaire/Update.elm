module Common.Questionnaire.Update exposing (update)

import ActionResult exposing (ActionResult(..))
import ChartJS exposing (encodeChartConfig)
import Common.Api.Feedbacks as FeedbacksApi
import Common.Api.Questionnaires as QuestionnairesApi
import Common.Api.TypeHints as TypeHintsApi
import Common.ApiError exposing (ApiError, getServerError)
import Common.AppState exposing (AppState)
import Common.FormEngine.Model exposing (TypeHint, setTypeHintsResult)
import Common.FormEngine.Msgs
import Common.FormEngine.Update exposing (updateForm)
import Common.Locale exposing (lg)
import Common.Questionnaire.Models exposing (..)
import Common.Questionnaire.Models.Feedback exposing (Feedback)
import Common.Questionnaire.Models.FeedbackForm as FeedbackForm
import Common.Questionnaire.Models.SummaryReport exposing (SummaryReport)
import Common.Questionnaire.Msgs exposing (CustomFormMessage(..), Msg(..))
import Form exposing (Form)
import KMEditor.Common.Events.Event exposing (Event)
import KMEditor.Common.KnowledgeModel.Chapter exposing (Chapter)
import KMEditor.Common.KnowledgeModel.KnowledgeModel as KnowledgeModel
import Ports
import Questionnaires.Common.QuestionnaireDetail as QuestionnaireDetail
import Questionnaires.Common.QuestionnaireTodo as QuestionnaireTodo exposing (QuestionnaireTodo)
import Utils exposing (stringToInt, withNoCmd)


update : Msg -> AppState -> Model -> ( Model, Cmd Msg )
update msg appState model =
    case msg of
        FormMsg formMsg ->
            handleFormMsg formMsg appState model

        SetLevel level ->
            handleSetLevel model level

        SetActiveChapter chapter ->
            handleSetActiveChapter appState model chapter

        ViewTodos ->
            handleViewTodos model

        ViewSummaryReport ->
            handleViewSummaryReport appState model

        PostForSummaryReportCompleted result ->
            handlePostForSummaryReportCompleted appState model result

        CloseFeedback ->
            handleCloseFeedback model

        FeedbackFormMsg formMsg ->
            handleFeedbackFormMsg formMsg model

        SendFeedbackForm ->
            handleSendFeedbackForm appState model

        PostFeedbackCompleted result ->
            handlePostFeedbackCompleted appState model result

        GetFeedbacksCompleted result ->
            handleGetFeedbacksCompleted appState model result

        GetTypeHintsCompleted result ->
            handleGetTypeHintsCompleted appState model result

        ScrollToTodo todo ->
            handleScrollToTodo appState model todo



-- Handlers


handleFormMsg : Common.FormEngine.Msgs.Msg CustomFormMessage ApiError -> AppState -> Model -> ( Model, Cmd Msg )
handleFormMsg msg appState model =
    case model.activePage of
        PageChapter chapter form ->
            case msg of
                Common.FormEngine.Msgs.CustomQuestionMsg questionUuid customMsg ->
                    case customMsg of
                        FeedbackMsg ->
                            ( { model
                                | feedback = Loading
                                , feedbackQuestionUuid = Just questionUuid
                                , feedbackForm = FeedbackForm.initEmpty
                                , sendingFeedback = Unset
                                , feedbackResult = Nothing
                              }
                            , FeedbacksApi.getFeedbacks model.questionnaire.package.id questionUuid appState GetFeedbacksCompleted
                            )

                        AddTodo path ->
                            ( addLabel model path, Cmd.none )

                        RemoveTodo path ->
                            ( removeLabel model path, Cmd.none )

                _ ->
                    let
                        ( updatedForm, cmd ) =
                            updateForm msg appState form (loadTypeHints appState model.questionnaire.package.id model.events)

                        removeLabels newModel =
                            case msg of
                                Common.FormEngine.Msgs.GroupItemRemove path index ->
                                    removeLabelsFromItem newModel path index

                                _ ->
                                    newModel
                    in
                    ( removeLabels <|
                        updateReplies
                            { model
                                | activePage = PageChapter chapter updatedForm
                                , dirty = True
                            }
                    , Cmd.map FormMsg cmd
                    )

        _ ->
            ( model, Cmd.none )


handleSetLevel : Model -> String -> ( Model, Cmd Msg )
handleSetLevel model level =
    ( { model
        | questionnaire = setLevel model.questionnaire <| stringToInt level
        , dirty = True
      }
    , Cmd.none
    )


handleSetActiveChapter : AppState -> Model -> Chapter -> ( Model, Cmd Msg )
handleSetActiveChapter appState model chapter =
    model
        |> updateReplies
        |> setActiveChapter appState chapter
        |> withNoCmd


handleViewTodos : Model -> ( Model, Cmd Msg )
handleViewTodos model =
    withNoCmd <|
        { model | activePage = PageTodos }


handleViewSummaryReport : AppState -> Model -> ( Model, Cmd Msg )
handleViewSummaryReport appState model =
    let
        newModel =
            updateReplies model

        body =
            QuestionnaireDetail.encode newModel.questionnaire

        cmd =
            QuestionnairesApi.fetchSummaryReport model.questionnaire.uuid body appState PostForSummaryReportCompleted
    in
    ( { newModel
        | activePage = PageSummaryReport
        , summaryReport = Loading
      }
    , cmd
    )


handlePostForSummaryReportCompleted : AppState -> Model -> Result ApiError SummaryReport -> ( Model, Cmd Msg )
handlePostForSummaryReportCompleted appState model result =
    case result of
        Ok summaryReport ->
            let
                chapters =
                    KnowledgeModel.getChapters model.questionnaire.knowledgeModel

                cmds =
                    List.map
                        (Ports.drawMetricsChart
                            << encodeChartConfig
                            << createChartConfig model.metrics chapters
                        )
                        summaryReport.chapterReports
            in
            ( { model | summaryReport = Success summaryReport }
            , Cmd.batch cmds
            )

        Err error ->
            ( { model | summaryReport = getServerError error <| lg "apiError.questionnaires.summaryReport.fetchError" appState }, Cmd.none )


handleCloseFeedback : Model -> ( Model, Cmd Msg )
handleCloseFeedback model =
    withNoCmd <|
        { model | feedback = Unset, feedbackQuestionUuid = Nothing }


handleFeedbackFormMsg : Form.Msg -> Model -> ( Model, Cmd Msg )
handleFeedbackFormMsg formMsg model =
    withNoCmd <|
        { model | feedbackForm = Form.update FeedbackForm.validation formMsg model.feedbackForm }


handleSendFeedbackForm : AppState -> Model -> ( Model, Cmd Msg )
handleSendFeedbackForm appState model =
    let
        newFeedbackForm =
            Form.update FeedbackForm.validation Form.Submit model.feedbackForm
    in
    case Form.getOutput newFeedbackForm of
        Just feedbackForm ->
            let
                body =
                    FeedbackForm.encode (model.feedbackQuestionUuid |> Maybe.withDefault "") model.questionnaire.package.id feedbackForm

                cmd =
                    FeedbacksApi.postFeedback body appState PostFeedbackCompleted
            in
            ( { model | feedbackForm = newFeedbackForm, sendingFeedback = Loading }, cmd )

        _ ->
            ( { model | feedbackForm = newFeedbackForm }, Cmd.none )


handlePostFeedbackCompleted : AppState -> Model -> Result ApiError Feedback -> ( Model, Cmd Msg )
handlePostFeedbackCompleted appState model result =
    withNoCmd <|
        case result of
            Ok feedback ->
                { model
                    | sendingFeedback = Success <| lg "apiSuccess.feedbacks.post" appState
                    , feedbackResult = Just feedback
                }

            Err error ->
                { model | sendingFeedback = getServerError error <| lg "apiError.feedbacks.postError" appState }


handleGetFeedbacksCompleted : AppState -> Model -> Result ApiError (List Feedback) -> ( Model, Cmd Msg )
handleGetFeedbacksCompleted appState model result =
    case model.feedback of
        Loading ->
            case result of
                Ok feedback ->
                    ( { model | feedback = Success feedback }, Cmd.none )

                Err error ->
                    ( { model | feedback = getServerError error <| lg "apiError.feedbacks.getError" appState }, Cmd.none )

        _ ->
            ( model, Cmd.none )


handleGetTypeHintsCompleted : AppState -> Model -> Result ApiError (List TypeHint) -> ( Model, Cmd Msg )
handleGetTypeHintsCompleted appState model result =
    case model.activePage of
        PageChapter chapter form ->
            let
                actionResult =
                    case result of
                        Ok typeHints ->
                            Success typeHints

                        Err err ->
                            getServerError err <| lg "apiError.typeHints.getListError" appState
            in
            ( { model | activePage = PageChapter chapter <| setTypeHintsResult actionResult form }
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )


handleScrollToTodo : AppState -> Model -> QuestionnaireTodo -> ( Model, Cmd Msg )
handleScrollToTodo appState model todo =
    let
        selector =
            "[data-path=\"" ++ QuestionnaireTodo.getSelectorPath todo ++ "\"]"
    in
    ( setActiveChapter appState todo.chapter model
    , Ports.scrollIntoView selector
    )



-- Helpers


loadTypeHints : AppState -> String -> List Event -> String -> String -> (Result ApiError (List TypeHint) -> msg) -> Cmd msg
loadTypeHints appState packageId events questionUuid q toMsg =
    let
        mbPackageId =
            if String.isEmpty packageId then
                Nothing

            else
                Just packageId
    in
    TypeHintsApi.fetchTypeHints mbPackageId events questionUuid q appState toMsg
