module Questionnaires.Common.Models exposing (Questionnaire, questionnaireDecoder, questionnaireListDecoder)

import Json.Decode as Decode exposing (..)
import Json.Decode.Pipeline exposing (required)
import KnowledgeModels.Common.Models exposing (PackageDetail, packageDetailDecoder)


type alias Questionnaire =
    { uuid : String
    , name : String
    , package : PackageDetail
    , private : Bool
    }


questionnaireDecoder : Decoder Questionnaire
questionnaireDecoder =
    Decode.succeed Questionnaire
        |> required "uuid" Decode.string
        |> required "name" Decode.string
        |> required "package" packageDetailDecoder
        |> required "private" Decode.bool


questionnaireListDecoder : Decoder (List Questionnaire)
questionnaireListDecoder =
    Decode.list questionnaireDecoder