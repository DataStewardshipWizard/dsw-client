module Questionnaires.View exposing (view)

import Common.AppState exposing (AppState)
import Html exposing (Html)
import Msgs
import Questionnaires.Create.View
import Questionnaires.Detail.View
import Questionnaires.Edit.View
import Questionnaires.Index.View
import Questionnaires.Migration.View
import Questionnaires.Models exposing (Model)
import Questionnaires.Msgs exposing (Msg(..))
import Questionnaires.Routing exposing (Route(..))


view : Route -> (Msg -> Msgs.Msg) -> AppState -> Model -> Html Msgs.Msg
view route wrapMsg appState model =
    case route of
        Create _ ->
            Questionnaires.Create.View.view (wrapMsg << CreateMsg) model.createModel

        Detail uuid ->
            Questionnaires.Detail.View.view (wrapMsg << DetailMsg) appState model.detailModel

        Edit uuid ->
            Questionnaires.Edit.View.view (wrapMsg << EditMsg) model.editModel

        Index ->
            Questionnaires.Index.View.view (wrapMsg << IndexMsg) appState model.indexModel

        Migration uuid ->
            Questionnaires.Migration.View.view (wrapMsg << MigrationMsg) model.migrationModel
