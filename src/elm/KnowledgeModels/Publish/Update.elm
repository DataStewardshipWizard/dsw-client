module KnowledgeModels.Publish.Update exposing (..)

import Auth.Models exposing (Session)
import Common.Types exposing (ActionResult(..))
import Form
import Jwt
import KnowledgeModels.Models exposing (..)
import KnowledgeModels.Publish.Models exposing (Model)
import KnowledgeModels.Publish.Msgs exposing (Msg(..))
import KnowledgeModels.Requests exposing (getKnowledgeModel, putKnowledgeModelVersion)
import Msgs
import Requests exposing (toCmd)
import Routing exposing (Route(..), cmdNavigate)


getKnowledgeModelCmd : String -> Session -> Cmd Msgs.Msg
getKnowledgeModelCmd uuid session =
    getKnowledgeModel uuid session
        |> toCmd GetKnowledgeModelCompleted Msgs.KnowledgeModelsPublishMsg


putKnowledgeModelVersionCmd : Session -> KnowledgeModelPublishForm -> String -> Cmd Msgs.Msg
putKnowledgeModelVersionCmd session form uuid =
    let
        ( version, data ) =
            encodeKnowledgeModelPublishForm form
    in
    putKnowledgeModelVersion uuid version data session
        |> toCmd PutKnowledgeModelVersionCompleted Msgs.KnowledgeModelsPublishMsg


getKnowledgeModelCompleted : Model -> Result Jwt.JwtError KnowledgeModel -> ( Model, Cmd Msgs.Msg )
getKnowledgeModelCompleted model result =
    let
        newModel =
            case result of
                Ok knowledgeModel ->
                    { model | knowledgeModel = Success knowledgeModel }

                Err error ->
                    let
                        a =
                            error |> Debug.log "error"
                    in
                    { model | knowledgeModel = Error "Unable to get the knowledge model." }
    in
    ( newModel, Cmd.none )


putKnowledgeModelVersionCompleted : Model -> Result Jwt.JwtError String -> ( Model, Cmd Msgs.Msg )
putKnowledgeModelVersionCompleted model result =
    case result of
        Ok version ->
            ( model, cmdNavigate PackageManagement )

        Err error ->
            ( { model | publishingKnowledgeModel = Error "Publishing new version failed" }, Cmd.none )


handleForm : Form.Msg -> Session -> Model -> ( Model, Cmd Msgs.Msg )
handleForm formMsg session model =
    case ( formMsg, Form.getOutput model.form, model.knowledgeModel ) of
        ( Form.Submit, Just form, Success km ) ->
            let
                cmd =
                    putKnowledgeModelVersionCmd session form km.uuid
            in
            ( { model | publishingKnowledgeModel = Loading }, cmd )

        _ ->
            let
                form =
                    Form.update knowledgeModelPublishFormValidation formMsg model.form
            in
            ( { model | form = form }, Cmd.none )


update : Msg -> Session -> Model -> ( Model, Cmd Msgs.Msg )
update msg session model =
    case msg of
        GetKnowledgeModelCompleted result ->
            getKnowledgeModelCompleted model result

        FormMsg msg ->
            handleForm msg session model

        PutKnowledgeModelVersionCompleted result ->
            putKnowledgeModelVersionCompleted model result