module KMEditor.Common.Events.EditReferenceEventData exposing
    ( EditReferenceEventData(..)
    , decoder
    , encode
    , getEntityVisibleName
    , map
    )

import Json.Decode as D exposing (Decoder)
import Json.Encode as E
import KMEditor.Common.Events.EditReferenceCrossEventData as EditReferenceCrossEventData exposing (EditReferenceCrossEventData)
import KMEditor.Common.Events.EditReferenceResourcePageEventData as EditReferenceResourcePageEventData exposing (EditReferenceResourcePageEventData)
import KMEditor.Common.Events.EditReferenceURLEventData as EditReferenceURLEventData exposing (EditReferenceURLEventData)
import KMEditor.Common.Events.EventField as EventField


type EditReferenceEventData
    = EditReferenceResourcePageEvent EditReferenceResourcePageEventData
    | EditReferenceURLEvent EditReferenceURLEventData
    | EditReferenceCrossEvent EditReferenceCrossEventData


decoder : Decoder EditReferenceEventData
decoder =
    D.field "referenceType" D.string
        |> D.andThen
            (\referenceType ->
                case referenceType of
                    "ResourcePageReference" ->
                        D.map EditReferenceResourcePageEvent EditReferenceResourcePageEventData.decoder

                    "URLReference" ->
                        D.map EditReferenceURLEvent EditReferenceURLEventData.decoder

                    "CrossReference" ->
                        D.map EditReferenceCrossEvent EditReferenceCrossEventData.decoder

                    _ ->
                        D.fail <| "Unknown reference type: " ++ referenceType
            )


encode : EditReferenceEventData -> List ( String, E.Value )
encode data =
    let
        eventData =
            map
                EditReferenceResourcePageEventData.encode
                EditReferenceURLEventData.encode
                EditReferenceCrossEventData.encode
                data
    in
    [ ( "eventType", E.string "EditReferenceEvent" ) ] ++ eventData


getEntityVisibleName : EditReferenceEventData -> Maybe String
getEntityVisibleName =
    EventField.getValue << map .shortUuid .label .targetUuid


map :
    (EditReferenceResourcePageEventData -> a)
    -> (EditReferenceURLEventData -> a)
    -> (EditReferenceCrossEventData -> a)
    -> EditReferenceEventData
    -> a
map resourcePageReference urlReference crossReference reference =
    case reference of
        EditReferenceResourcePageEvent data ->
            resourcePageReference data

        EditReferenceURLEvent data ->
            urlReference data

        EditReferenceCrossEvent data ->
            crossReference data
