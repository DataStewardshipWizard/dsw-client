module PackageManagement.Detail.View exposing (..)

import Common.Html exposing (emptyNode, linkTo)
import Common.Types exposing (ActionResult(..))
import Common.View exposing (defaultFullPageError, fullPageLoader, modalView, pageHeader)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Msgs exposing (Msg)
import PackageManagement.Detail.Models exposing (..)
import PackageManagement.Detail.Msgs exposing (..)
import PackageManagement.Models exposing (..)
import PackageManagement.Requests exposing (exportPackageUrl)
import Routing exposing (Route(..))


view : Model -> Html Msgs.Msg
view model =
    div []
        [ content model
        , deleteModal model
        , deleteVersionModal model
        ]


content : Model -> Html Msgs.Msg
content model =
    case model.packages of
        Unset ->
            emptyNode

        Loading ->
            fullPageLoader

        Error err ->
            defaultFullPageError err

        Success packages ->
            packageDetail packages


deleteModal : Model -> Html Msgs.Msg
deleteModal model =
    let
        version =
            case currentPackage model of
                Just package ->
                    package.groupId ++ ":" ++ package.artifactId

                Nothing ->
                    ""

        modalContent =
            [ p []
                [ text "Are you sure you want to permanently delete "
                , strong [] [ text version ]
                , text " and all its versions?"
                ]
            ]

        modalConfig =
            { modalTitle = "Delete package"
            , modalContent = modalContent
            , visible = model.showDeleteDialog
            , actionResult = model.deletingPackage
            , actionName = "Delete"
            , actionMsg = Msgs.PackageManagementDetailMsg DeletePackage
            , cancelMsg = Msgs.PackageManagementDetailMsg <| ShowHideDeleteDialog False
            }
    in
    modalView modalConfig


deleteVersionModal : Model -> Html Msgs.Msg
deleteVersionModal model =
    let
        ( version, visible ) =
            case model.versionToBeDeleted of
                Just version ->
                    ( version, True )

                Nothing ->
                    ( "", False )

        modalContent =
            [ p []
                [ text "Are you sure you want to permanently delete version "
                , strong [] [ text version ]
                , text "?"
                ]
            ]

        modalConfig =
            { modalTitle = "Delete version"
            , modalContent = modalContent
            , visible = visible
            , actionResult = model.deletingVersion
            , actionName = "Delete"
            , actionMsg = Msgs.PackageManagementDetailMsg DeleteVersion
            , cancelMsg = Msgs.PackageManagementDetailMsg <| ShowHideDeleteVersion Nothing
            }
    in
    modalView modalConfig


packageDetail : List PackageDetail -> Html Msgs.Msg
packageDetail packages =
    case List.head packages of
        Just package ->
            div [ class "col-xs-12 col-lg-10 col-lg-offset-1" ]
                [ pageHeader package.name actions
                , code [ class "package-artifact-id" ]
                    [ text (package.groupId ++ ":" ++ package.artifactId) ]
                , h3 [] [ text "Versions" ]
                , div [] (List.map versionView packages)
                ]

        Nothing ->
            text ""


actions : List (Html Msgs.Msg)
actions =
    [ linkTo PackageManagement [ class "btn btn-default" ] [ text "Back" ]
    , button
        [ onClick (Msgs.PackageManagementDetailMsg <| ShowHideDeleteDialog True)
        , class "btn btn-danger"
        ]
        [ text "Delete" ]
    ]


versionView : PackageDetail -> Html Msgs.Msg
versionView detail =
    let
        url =
            exportPackageUrl detail.id
    in
    div [ class "panel panel-default panel-version" ]
        [ div [ class "panel-body" ]
            [ div [ class "labels" ]
                [ strong [] [ text detail.version ]
                , text detail.description
                ]
            , div [ class "actions" ]
                [ a [ class "btn btn-info link-with-icon", href url, target "_blank" ] [ i [ class "fa fa-download" ] [], text "Export" ]
                , button
                    [ onClick (Msgs.PackageManagementDetailMsg <| ShowHideDeleteVersion <| Just detail.id)
                    , class "btn btn-default"
                    ]
                    [ i [ class "fa fa-trash" ] [] ]
                ]
            ]
        ]