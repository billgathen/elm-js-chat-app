module Main where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

-- Elm programs follow the model-update-view structure.
-- The model contains all the state for the app, and when
-- a change event occurs (an action), the action and the
-- model are fed into the update function, which returns
-- a copy of the model with the appropriate changes applied.
-- The new model is passed to the view function, which re-renders
-- the HTML based on the state. Elm itself uses the updated
-- HTML to determine what changes to make to the actual page.

-- MODEL

-- `type alias` means "when I say 'Model', I mean a structure
-- that looks like this." In our case, it's a record (basically a
-- JavaScript object without methods) containing two properties:
-- field (a String) and messages (a List of Strings)
type alias Model =
  {
    field : String,
    messages : List String
  }

-- We'll need to bootstrap the app with default state, so we
-- create a function that returns a record that matches the Model
-- structure. The function declaration formally announces that this
-- function returns a Model, but Elm has type inference (i.e., it can
-- figure that out on its own) so it's optional. Still, I think it's
-- good documentation.
initialModel : Model
initialModel =
  {
    field = "",
    messages = [ ]
  }

-- UPDATE

-- We need to explicitly define every legal action for the update function.
-- To do that, we create an enumeration called Action.
-- In our case there are four, the last three of which will always appear with
-- a String attached. The pipes separate each of the options.

type Action = NoOp | JsMessage String | ElmMessage String | UpdateField String

-- The update function accepts the action and the current model, returning a
-- copy (Elm data structures are immutable!) of the model with the necessary
-- changes applied.
-- The case statement identifies which type of action we received. Note that the
-- actions with associated Strings have a variable in the signature: the value
-- will be automatically stored in this temporary variable so we can use it in
-- the model update.
-- The { thing | property <- algorithm } pattern is how we get changes into the
-- model. It copies the model, pushes the result of the algorithm into the
-- property you supply, then returns the copy.
--
-- NoOp is the exception: it returns the model unchanged. This is the secret
-- sauce of immutability: when Elm sees that the returned model is the same object
-- as the passed-in model, it can skip all the "what should change in the view"
-- logic, because nothing CAN change!

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

-- The view maintains all of the HTML for an Elm program.
-- It uses the virtual DOM to quickly build up the complete structure
-- of your app, then compares it against the existing structure to
-- see what (if anything) needs to change.
--
-- Like React, it renders the complete view every time, but the
-- virtual DOM is so fast, this is a big speed increase over making
-- selected changes to the DOM directly.
--
-- The Html, Html.Attributes and Html.Events modules give us all
-- the tools we need to build up our HTML.
-- Each HTML element (except text) accepts two Lists: the first is
-- the HTML attributes (id, class, event handlers, etc) and the
-- second is the contents (the nested elements).
--
-- The view accepts an address (a target for signals: we'll come back
-- to this) and the current model.
-- The interesting parts are the `on "input"` and `onClick` event
-- generators. These correlate to their JS cousins, sending actions
-- back into the Elm system and triggering the model-update-view cycle.
--
-- The only place I've found solid docs on the event generators is
-- in Pragmatic Studio's video course (the 2nd one, on signals).
-- Highly-recommended!

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

-- Modularity is encouraged in the Elm ecosystem, so messageList is
-- syntactic sugar around creating an HTML unordered list from a
-- List of Strings. We call it from the last line of the view function,
-- passing in model.messages.
messageList : List String -> Html
messageList messages =
  let
    messageItem message =
      li [ ] [ text message ]
    messageItems =
      List.map messageItem messages
  in
    ul [ ] messageItems

-- SIGNALS

-- Signals are values which can change over time. Think "streams".
-- We can filter them, merge them and transform (aka map) them to
-- more-useful forms. Signals are what drive the interactivity of
-- Elm apps.

-- A mailbox is a landing spot for signals. In this case, a signal of Actions.
-- This is the "funnel" at the top of the model-update-view flow.
inbox : Signal.Mailbox Action
inbox =
  Signal.mailbox NoOp -- We "prime" the signal with a NoOp

-- We create a syntactic sugar method around the
-- inbox's signal so we know that it wraps actions
actions : Signal Action
actions =
  -- We want this signal to reflect either action, so we merge them into one
  -- messagesFromJavaScript is a signal of STRINGS, not ACTIONS, so we need to wrap
  -- them first so they'll match the signal type
  Signal.merge inbox.signal (Signal.map JsMessage messagesFromJavaScript)

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
elmMessages : Signal String
elmMessages =
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

-- This is merged into the system in the actions function
-- When you set up a port, Elm wires it to a signal of the same name
-- Once the signal is created, we can treat it like any other Elm signal.
-- Elm has no idea the initiating event came from the outside world.
port messagesFromJavaScript : Signal String

port messagesFromElm : Signal String
port messagesFromElm =
  elmMessages

-- MAIN

main : Signal Html
main =
  -- Need to partially-apply the view function because map
  -- requires a function that takes one argument: the model
  Signal.map (view inbox.address) model
