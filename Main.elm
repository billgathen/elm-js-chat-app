module Main where

-- `exposing (..)` means "add all my functions into the module namespace"
-- so we can call `div` instead of `Html.div`, etc.
-- If we prefer, We can be more specific by supplying a list of function names
-- instead of the double-dot.
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

-- For this chat app, we'll need to keep track of two pieces of state:
-- 1. `field` - the current contents of the textarea, updated every time we type
-- 2. `messages` - all the previously-submitted messages (from Elm or JS)

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
--
-- The case statement identifies which type of action we received. Note that the
-- actions with associated Strings have a variable in the signature: the value
-- will be automatically stored in this temporary variable so we can use it in
-- the model update.
--
-- The { thing | property <- algorithm } pattern is how we get changes into the
-- model. It copies the model, pushes the result of the algorithm into the
-- property you supply, then returns the copy.
--
-- NoOp is the exception: it returns the model unchanged. This is the secret
-- sauce of immutability: when Elm sees that the returned model is the same object
-- as the passed-in model, it can skip all the "what should change in the view"
-- logic, because nothing CAN change!
--
-- `model.messages ++ [ message ]` means "append this message to the end of the
-- `messages` List on the model".
--
-- `field <- fieldContent` replaces the existing
-- value of `field` on the model with whatever the action passed-in.

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

-- The view renders the HTML for an Elm program.
-- It uses the virtual DOM to quickly build up the complete structure
-- of your app, then the `main` function compares that against
-- the existing page to see what (if anything) needs to change.
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
-- back into the Elm "funnel" and triggering the model-update-view cycle.
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
--
-- The address variable we handed to the view function allows us to
-- push new values to this signal (which we did with the on and onClick helpers)
inbox : Signal.Mailbox Action
inbox =
  Signal.mailbox NoOp -- We "prime" the signal with a NoOp

-- However, some of our actions are coming from another source, the
-- messagesFromJavaScript port. We'll discuss ports in a bit.
-- In order to have one signal to listen to, we use Signal.merge
-- to combine the values from inbox and messagesFromJavaScript.
-- The resulting signal is called actions.
actions : Signal Action
actions =
  -- messagesFromJavaScript is a signal of STRINGS, not ACTIONS, so we
  -- use Signal.map to wrap them in a JsMessage action so they'll match the signal type
  Signal.merge inbox.signal (Signal.map JsMessage messagesFromJavaScript)

-- Every time the actions signal changes (we get a click from our button, for
-- example, or receive a JS message), we trigger a foldp, applying the changes
-- to our model.
--
-- foldp means "fold into the past", so update must know
-- how to adjust the model when each type of action appears
--
-- The model function returns a signal of models, which we'll hand to
-- our view function so it can re-render itself and tell
-- the main function to update the page
model : Signal Model
model =
  Signal.foldp update initialModel actions

-- We also have to send our ElmMessages back to JavaScript land!
-- elmMessages is a signal that wraps the flow of actions.
-- For every ElmMessage, we pass along the value. Otherwise we return Nothing.
-- .filterMap throws away the Nothing results, giving
-- us a Signal of strings that change for every outgoing message
elmMessages : Signal String
elmMessages =
  let
    -- A let expression gives us a place to create an algorithm or
    -- hold a temporary variable that we'll use in the main body of
    -- the function. Here we write an isElmMessage function that
    -- return either a Just (with the associated message String)
    -- or Nothing.
    isElmMessage act =
      case act of
        ElmMessage t -> Just t
        NoOp -> Nothing
        JsMessage t  -> Nothing
        UpdateField t -> Nothing
  in
    Signal.filterMap isElmMessage "" actions

-- PORTS

-- Ports are holes to the outside world. There are incoming ports (which
-- we'll use to receive messages from JavaScript) and outgoing ports
-- (which we'll use to send messages to JavaScript)

-- messagesFromJavaScript is an incoming port.
-- When you set up a port, Elm wires it to a signal of the same name
-- Once the signal is created, we can treat it like any other Elm signal.
-- Elm has no idea the initiating event came from the outside world.
port messagesFromJavaScript : Signal String

-- messagesFromElm is an outgoing port, a thin wrapper around the elmMessages signal.
-- Whenever we change the value of the signal, it will be echoed to
-- JavaScript. We'll subscribe to this port in JavaScript and supply
-- a callback to be executed every time the signal changes.
port messagesFromElm : Signal String
port messagesFromElm =
  elmMessages

-- MAIN

-- main is where the app bootstraps itself.
-- We map the model signal (which changes every time we receive a new action)
-- onto the view, so it can re-render the virtual DOM in response.
-- The main function itself expects a signal of HTML (which view returns)
-- and it analyzes the differences between the virtual DOM and the actual
-- page, sending change actions to make the page match. This makes re-renders
-- extremely fast.
--
-- One oddity is that Signal.map expects a function that takes one argument,
-- but view takes 2 (the address for sending actions to and the model).
-- To solve this problem, we "partially-apply" (or curry) the view function,
-- passing it only the first argument. We get back a one-argument function
-- that remembers the address and expects a model. This one-argument function
-- can be used with Signal.map, so we're done!

main : Signal Html
main =
  Signal.map (view inbox.address) model
