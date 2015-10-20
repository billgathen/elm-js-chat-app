// Embed Elm
var elmDiv = document.getElementById('elm');
var elm = Elm.embed(Elm.Main, elmDiv, { javascriptMessages: "" });

// Grab JS-driven elements
var jsMsgButton = document.getElementById('js-msg-button');
var jsMsg = document.getElementById('js-msg');
var msgs = document.getElementById('messages');

// Connect to Elm
// Send value of textarea on button click
jsMsgButton.onclick = function() {
  var msg = jsMsg.value;

  elm.ports.javascriptMessages.send(msg);

  appendMessage(msg);

  jsMsg.value = '';
};

// Get message sent from Elm
elm.ports.elmMessages.subscribe(function(e) {
  appendMessage(e);
});

function appendMessage(msg) {
  var li = document.createElement('li');
  li.textContent = msg;
  msgs.appendChild(li);
}
