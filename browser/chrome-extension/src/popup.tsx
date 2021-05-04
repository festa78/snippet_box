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
  return (
    <>
      <ul>
        <li>Current URL: {currentURL}</li>
        <li>Current Time: {new Date().toLocaleTimeString()}</li>
        <li>User ID: {uid}</li>
      </ul>
      <button
        onClick={() => SendUriToDb(currentURL)}
      >
        Save current URL to SnippetBox
      </button>
    </>
  );
};

//   const [count, setCount] = useState(0);
//   const [currentURL, setCurrentURL] = useState<string>();

//   useEffect(() => {
//     chrome.browserAction.setBadgeText({ text: count.toString() });
//   }, [count]);

//   useEffect(() => {
//     chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
//       setCurrentURL(tabs[0].url);
//     });
//   }, []);

//   const changeBackground = () => {
//     chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
//       const tab = tabs[0];
//       if (tab.id) {
//         chrome.tabs.sendMessage(
//           tab.id,
//           {
//             color: "#555555",
//           },
//           (msg) => {
//             console.log("result message:", msg);
//           }
//         );
//       }
//     });
//   };

//   return (
//     <>
//       <ul style={{ minWidth: "700px" }}>
//         <li>Current URL: {currentURL}</li>
//         <li>Current Time: {new Date().toLocaleTimeString()}</li>
//       </ul>
//       <button
//         onClick={() => setCount(count + 1)}
//         style={{ marginRight: "5px" }}
//       >
//         count up
//       </button>
//       <button onClick={changeBackground}>change background</button>
//     </>
//   );
// };

ReactDOM.render(
  <React.StrictMode>
    <Popup />
  </React.StrictMode>,
  document.getElementById("root")
);
