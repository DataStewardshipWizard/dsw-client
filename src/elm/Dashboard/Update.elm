module Dashboard.Update exposing (fetchData, update)

import Common.Api exposing (applyResult)
import Common.Api.Levels as LevelsApi
import Common.Api.Questionnaires as QuestionnairesApi
import Common.AppState as AppState exposing (AppState)
import Common.Config exposing (Widget(..))
import Common.Locale exposing (lg)
import Common.Setters exposing (setLevels, setQuestionnaires)
import Dashboard.Models as Model exposing (Model)
import Dashboard.Msgs exposing (Msg(..))
import Msgs


fetchData : AppState -> Cmd Msg
fetchData appState =
    let
        widgets =
            AppState.getDashboardWidgets appState
    in
    if List.any (\w -> w == DMPWorkflow || w == LevelsQuestionnaire) widgets then
        Cmd.batch
            [ LevelsApi.getLevels appState GetLevelsCompleted
            , QuestionnairesApi.getQuestionnaires appState GetQuestionnairesCompleted
            ]

    else
        Cmd.none


update : Msg -> AppState -> Model -> ( Model, Cmd Msgs.Msg )
update msg appState model =
    case msg of
        GetLevelsCompleted result ->
            applyResult
                { setResult = setLevels
                , defaultError = lg "apiError.levels.getListError" appState
                , model = model
                , result = result
                }

        GetQuestionnairesCompleted result ->
            applyResult
                { setResult = setQuestionnaires
                , defaultError = lg "apiError.questionnaires.getListError" appState
                , model = model
                , result = result
                }
