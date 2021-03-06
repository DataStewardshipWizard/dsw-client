module KMEditor.Editor.Update exposing
    ( fetchData
    , isGuarded
    , update
    )

import ActionResult exposing (ActionResult(..))
import Common.Api exposing (getResultCmd)
import Common.Api.Branches as BranchesApi
import Common.Api.KnowledgeModels as KnowledgeModelsApi
import Common.Api.Levels as LevelsApi
import Common.Api.Metrics as MetricsApi
import Common.ApiError exposing (getServerError)
import Common.AppState exposing (AppState)
import Common.Locale exposing (l, lg)
import KMEditor.Common.BranchDetail exposing (BranchDetail)
import KMEditor.Editor.KMEditor.Models
import KMEditor.Editor.KMEditor.Update exposing (generateEvents)
import KMEditor.Editor.Models exposing (EditorType(..), Model, addSessionEvents, containsChanges, initialModel)
import KMEditor.Editor.Msgs exposing (Msg(..))
import KMEditor.Editor.Preview.Models
import KMEditor.Editor.Preview.Update
import KMEditor.Editor.TagEditor.Models as TagEditorModel
import KMEditor.Editor.TagEditor.Update
import Maybe.Extra exposing (isJust)
import Msgs
import Ports
import Random exposing (Seed)
import Task


l_ : String -> AppState -> String
l_ =
    l "KMEditor.Editor.Update"


fetchData : String -> AppState -> Cmd Msg
fetchData uuid appState =
    Cmd.batch
        [ BranchesApi.getBranch uuid appState GetKnowledgeModelCompleted
        , MetricsApi.getMetrics appState GetMetricsCompleted
        , LevelsApi.getLevels appState GetLevelsCompleted
        ]


isGuarded : AppState -> Model -> Maybe String
isGuarded appState model =
    if containsChanges model then
        Just <| l_ "unsavedChanges" appState

    else
        Nothing


update : Msg -> (Msg -> Msgs.Msg) -> AppState -> Model -> ( Seed, Model, Cmd Msgs.Msg )
update msg wrapMsg appState model =
    let
        updateResult =
            case msg of
                GetKnowledgeModelCompleted result ->
                    let
                        ( newModel, cmd ) =
                            case result of
                                Ok km ->
                                    fetchPreview wrapMsg appState { model | km = Success km }

                                Err error ->
                                    ( { model | km = getServerError error <| lg "apiError.branches.getError" appState }
                                    , getResultCmd result
                                    )
                    in
                    ( appState.seed, newModel, cmd )

                GetMetricsCompleted result ->
                    let
                        ( newModel, cmd ) =
                            case result of
                                Ok metrics ->
                                    fetchPreview wrapMsg appState { model | metrics = Success metrics }

                                Err error ->
                                    ( { model | metrics = getServerError error <| lg "apiError.metrics.getListError" appState }
                                    , getResultCmd result
                                    )
                    in
                    ( appState.seed, newModel, cmd )

                GetLevelsCompleted result ->
                    let
                        ( newModel, cmd ) =
                            case result of
                                Ok levels ->
                                    fetchPreview wrapMsg appState { model | levels = Success levels }

                                Err error ->
                                    ( { model | levels = getServerError error <| lg "apiError.levels.getListError" appState }
                                    , getResultCmd result
                                    )
                    in
                    ( appState.seed, newModel, cmd )

                GetPreviewCompleted result ->
                    let
                        newModel =
                            case result of
                                Ok km ->
                                    { model
                                        | preview = Success km
                                        , previewEditorModel =
                                            Just <|
                                                KMEditor.Editor.Preview.Models.initialModel
                                                    appState
                                                    km
                                                    (ActionResult.withDefault [] model.metrics)
                                                    ((ActionResult.withDefault [] <| ActionResult.map .events model.km) ++ model.sessionEvents)
                                                    (ActionResult.withDefault "" <| ActionResult.map (Maybe.withDefault "" << .previousPackageId) model.km)
                                        , tagEditorModel = Just <| TagEditorModel.initialModel km
                                        , editorModel =
                                            Just <|
                                                KMEditor.Editor.KMEditor.Models.initialModel
                                                    km
                                                    (ActionResult.withDefault [] model.metrics)
                                                    (ActionResult.withDefault [] model.levels)
                                                    ((ActionResult.withDefault [] <| ActionResult.map .events model.km) ++ model.sessionEvents)
                                    }

                                Err error ->
                                    { model | preview = getServerError error <| lg "apiError.knowledgeModels.preview.fetchError" appState }

                        cmd =
                            getResultCmd result
                    in
                    ( appState.seed, newModel, cmd )

                OpenEditor editor ->
                    let
                        ( newSeed, modelWithEvents ) =
                            applyCurrentEditorChanges appState appState.seed model

                        ( newModel, cmd ) =
                            fetchPreview wrapMsg appState { modelWithEvents | currentEditor = editor }
                    in
                    ( newSeed, newModel, cmd )

                PreviewEditorMsg previewMsg ->
                    let
                        ( previewEditorModel, cmd ) =
                            case model.previewEditorModel of
                                Just m ->
                                    let
                                        ( newPreviewEditorModel, newCmd ) =
                                            KMEditor.Editor.Preview.Update.update previewMsg appState m
                                    in
                                    ( Just newPreviewEditorModel
                                    , Cmd.map (wrapMsg << PreviewEditorMsg) newCmd
                                    )

                                Nothing ->
                                    ( Nothing, Cmd.none )
                    in
                    ( appState.seed, { model | previewEditorModel = previewEditorModel }, cmd )

                TagEditorMsg tagMsg ->
                    let
                        ( newTagEditorModel, cmd ) =
                            case model.tagEditorModel of
                                Just tagEditorModel ->
                                    let
                                        ( updatedTagEditorModel, updateCmd ) =
                                            KMEditor.Editor.TagEditor.Update.update tagMsg tagEditorModel
                                    in
                                    ( Just updatedTagEditorModel
                                    , Cmd.map (wrapMsg << TagEditorMsg) updateCmd
                                    )

                                Nothing ->
                                    ( Nothing, Cmd.none )
                    in
                    ( appState.seed, { model | tagEditorModel = newTagEditorModel }, cmd )

                KMEditorMsg editorMsg ->
                    let
                        ( newSeed, newEditorModel, cmd ) =
                            case model.editorModel of
                                Just editorModel ->
                                    let
                                        ( updatedSeed, updatedEditorModel, updateCmd ) =
                                            KMEditor.Editor.KMEditor.Update.update editorMsg appState editorModel (openEditorTask wrapMsg)
                                    in
                                    ( updatedSeed, Just updatedEditorModel, updateCmd )

                                Nothing ->
                                    ( appState.seed, Nothing, Cmd.none )
                    in
                    ( newSeed, { model | editorModel = newEditorModel }, cmd )

                Discard ->
                    let
                        ( newModel, cmd ) =
                            fetchPreview wrapMsg appState { model | sessionEvents = [] }
                    in
                    ( appState.seed
                    , newModel
                    , Cmd.batch [ Ports.clearUnloadMessage (), cmd ]
                    )

                Save ->
                    let
                        ( newSeed, newModel ) =
                            applyCurrentEditorChanges appState appState.seed model

                        ( newModel2, cmd ) =
                            if hasKMEditorAlert newModel.editorModel then
                                ( newModel, Cmd.none )

                            else
                                ( { newModel | saving = Loading }
                                , model.km
                                    |> ActionResult.map (putBranchCmd wrapMsg appState newModel)
                                    |> ActionResult.withDefault Cmd.none
                                )
                    in
                    ( newSeed, newModel2, cmd )

                SaveCompleted result ->
                    case result of
                        Ok _ ->
                            let
                                newModel =
                                    initialModel model.kmUuid
                            in
                            ( appState.seed
                            , { newModel | currentEditor = model.currentEditor }
                            , Cmd.batch
                                [ Ports.clearUnloadMessage ()
                                , Cmd.map wrapMsg <| fetchData model.kmUuid appState
                                ]
                            )

                        Err error ->
                            ( appState.seed
                            , { model | saving = getServerError error <| lg "apiError.branches.putError" appState }
                            , getResultCmd result
                            )
    in
    withSetUnloadMsgCmd appState updateResult


openEditorTask : (Msg -> Msgs.Msg) -> Cmd Msgs.Msg
openEditorTask wrapMsg =
    Task.perform (wrapMsg << OpenEditor) (Task.succeed KMEditor)


fetchPreview : (Msg -> Msgs.Msg) -> AppState -> Model -> ( Model, Cmd Msgs.Msg )
fetchPreview wrapMsg appState model =
    case ActionResult.combine3 model.km model.metrics model.levels of
        Success ( km, _, _ ) ->
            ( { model | preview = Loading }
            , Cmd.map wrapMsg <|
                KnowledgeModelsApi.fetchPreview km.previousPackageId (km.events ++ model.sessionEvents) [] appState GetPreviewCompleted
            )

        _ ->
            ( model, Cmd.none )


putBranchCmd : (Msg -> Msgs.Msg) -> AppState -> Model -> BranchDetail -> Cmd Msgs.Msg
putBranchCmd wrapMsg appState model km =
    Cmd.map wrapMsg <|
        BranchesApi.putBranch model.kmUuid km.name km.kmId (km.events ++ model.sessionEvents) appState SaveCompleted


applyCurrentEditorChanges : AppState -> Seed -> Model -> ( Seed, Model )
applyCurrentEditorChanges appState seed model =
    case ( model.currentEditor, model.preview ) of
        ( TagsEditor, Success km ) ->
            let
                ( newSeed, newEvents ) =
                    model.tagEditorModel
                        |> Maybe.map (TagEditorModel.generateEvents seed km)
                        |> Maybe.withDefault ( seed, [] )
            in
            ( newSeed, addSessionEvents newEvents model )

        ( KMEditor, Success km ) ->
            let
                map ( mapSeed, editorModel, _ ) =
                    ( mapSeed, editorModel.events, Just editorModel )

                ( newSeed, newEvents, newEditorModel ) =
                    model.editorModel
                        |> Maybe.map (map << generateEvents appState seed)
                        |> Maybe.withDefault ( seed, [], model.editorModel )
            in
            if hasKMEditorAlert newEditorModel then
                ( newSeed, { model | editorModel = newEditorModel } )

            else
                ( newSeed, addSessionEvents newEvents model )

        _ ->
            ( seed, model )


hasKMEditorAlert : Maybe KMEditor.Editor.KMEditor.Models.Model -> Bool
hasKMEditorAlert =
    Maybe.map (.alert >> isJust) >> Maybe.withDefault False


withSetUnloadMsgCmd : AppState -> ( a, Model, Cmd msg ) -> ( a, Model, Cmd msg )
withSetUnloadMsgCmd appState ( a, model, cmd ) =
    let
        newCmd =
            if containsChanges model then
                Cmd.batch [ cmd, Ports.setUnloadMessage <| l_ "unsavedChanges" appState ]

            else
                cmd
    in
    ( a, model, newCmd )
