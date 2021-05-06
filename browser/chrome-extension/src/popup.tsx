import React, { useEffect, useState } from "react";
import ReactDOM from "react-dom";

const SendUriToDb = (uri: string | undefined) => {
  if (uri === undefined) {
    console.error("Given URI is undefined.");
    alert("Given URI is undefined.");
    return;
  }
  console.log("Send URI to firebase DB", uri);

  chrome.runtime.sendMessage({ name: "saveUri", uri }, response => {
    if (response.status !== "200") {
      console.error("Error on sending URI", response.error);
      alert(response.error);
      return;
    }
    console.log("Send URI successfully:", uri);
  });

}

const Popup = () => {
  const [uid, setUid] = useState<string>("");
  const [currentURL, setCurrentURL] = useState<string>();
  const [isUrlSaved, setIsUrlSaved] = useState<boolean>(false);

  useEffect(() => {
    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      setCurrentURL(tabs[0].url);
    });
  }, []);

  const Login = () => {
    chrome.storage.sync.get("uid", ({ uid }) => {
      if (!uid) {
        // User is signed out.
        chrome.runtime.sendMessage({ name: "login" }, response => {
          if (response.status !== "200") {
            console.error("Error on login request", response.error);
            alert(response.error);
            return;
          }
          console.log("Login succeeded:", response.user);
          setUid(response.user.uid);
        });
      }

      setUid(uid);
    });
  }

  if (!uid) {
    // User is signed out.
    return (
      <>
        <ul>
          <li>Current URL: {currentURL}</li>
          <li>Current Time: {new Date().toLocaleTimeString()}</li>
          <li>User ID: Not logged in</li>
        </ul>
        <button
          onClick={() => Login()}
        >
          Log in
        </button>
      </>
    );
  }

  // User is signed in.
  let view: React.ReactElement;
  if (!isUrlSaved) {
    view = (
      <button
        onClick={() => {
          SendUriToDb(currentURL);
          setIsUrlSaved(true);
        }}
      >
        Save current URL to SnippetBox
      </button>
    );
  } else {
    view = (<p>"URL saved!"</p>);
  }

  return (
    <>
      <ul>
        <li>Current URL: {currentURL}</li>
        <li>Current Time: {new Date().toLocaleTimeString()}</li>
        <li>User ID: {uid}</li>
      </ul>
      {view}
    </>
  );
};

ReactDOM.render(
  <React.StrictMode>
    <Popup />
  </React.StrictMode>,
  document.getElementById("root")
);
