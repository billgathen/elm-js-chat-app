module Main where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

-- MODEL

type alias Model =
  {
    field : String,
    messages : List String
  }

initialModel : Model
initialModel =
  {
    field = "",
    messages = [ ]
  }

-- UPDATE

type Action = NoOp | JsMessage String | ElmMessage String | UpdateField String

update : Action -> Model -> Model
update action model =
  case action of
    NoOp
      -> model
    JsMessage message
      -> { model | messages <- model.messages ++ [ message ] }
    ElmMessage message
      -> { model | messages <- model.messages ++ [ message ] }
    UpdateField fieldContent
      -> { model | field <- fieldContent }

-- VIEW

messageList : List String -> Html
messageList messages =
  let
    messageItem message =
      li [ ] [ text message ]
    messageItems =
      List.map messageItem messages
  in
    ul [ ] messageItems

view : Signal.Address Action -> Model -> Html
view address model =
  div [ ]
  [
    h1 [] [ text "Elm" ],
    div [ class "text-entry-widget" ] [
      textarea [
        id "elm-msg",
        cols 70,
        rows 3,
        on "input" targetValue (Signal.message address << UpdateField)
        ] [ ],
      button
      [
        onClick address (ElmMessage model.field),
        id "elm-msg-button"
        ] [ text "Send" ]
        ],
      messageList model.messages
      ]

-- SIGNALS

-- A mailbox is a landing spot for signals
-- in this case, Action signals
inbox : Signal.Mailbox Action
inbox =
  Signal.mailbox NoOp -- We "prime" the signal with a NoOp

-- We create a syntactic sugar method around the
-- inbox's signal so we know that it wraps actions
actions : Signal Action
actions =
  -- We want this signal to reflect either action, so we merge them into one
  Signal.merge inbox.signal (Signal.map JsMessage javascriptMessages)

-- We use the update function every time the signal
-- changes to fold the action into the model
--
-- foldp means "fold into the past", so update must know
-- how to adjust the model when each type of action appears
--
-- What comes out is a changing model, which we'll hand to
-- our view function so it can re-render itself and tell
-- the main function to update the page
model : Signal Model
model =
  Signal.foldp update initialModel actions

-- Monitor the flow of actions. When we see an ElmMessage,
-- pass along the value. Otherwise return Nothing.
-- .filterMap will throw away the Nothing results, giving
-- us a Signal of strings that change for every outgoing message
messages : Signal String
messages =
  let
    isElmMessage act =
      case act of
        ElmMessage t -> Just t
        NoOp -> Nothing
        JsMessage t  -> Nothing
        UpdateField t -> Nothing
  in
    Signal.filterMap isElmMessage "" actions

-- PORTS

port javascriptMessages : Signal String

-- port elmMessages : Signal (List String)
port elmMessages : Signal String
port elmMessages =
  messages

-- MAIN

main : Signal Html
main =
  -- Need to partially-apply the view function because map
  -- requires a function that takes one argument: the model
  Signal.map (view inbox.address) model