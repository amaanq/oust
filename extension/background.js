const NATIVE_MESSAGING_HOST = "com.manic.oust";

// Policy force-installs this into the main browser profile too, and only the
// browser's command line, which the host can read, says it is a web app.
const keepList = new Promise((resolve) => {
  chrome.runtime.sendNativeMessage(
    NATIVE_MESSAGING_HOST,
    { config: true },
    (reply) => {
      if (chrome.runtime.lastError) {
        console.error("oust:", chrome.runtime.lastError.message);
        resolve(null);
        return;
      }
      resolve(reply?.keep ?? null);
    },
  );
});

function hostname(url) {
  try {
    return new URL(url).hostname;
  } catch {
    return null;
  }
}

const bounced = new Set();

async function consider(tabId, url) {
  if (!/^https?:\/\//.test(url)) return;
  const keep = await keepList;
  if (keep === null) return;
  const host = hostname(url);
  if (host === null) return;
  if (keep.some((d) => host === d || host.endsWith("." + d))) return;
  if (bounced.has(tabId)) return;

  let win;
  try {
    const tab = await chrome.tabs.get(tabId);
    win = await chrome.windows.get(tab.windowId);
  } catch {
    return;
  }
  // App and popup windows stay untouched so OAuth flows keep working.
  if (win.type !== "normal") return;

  bounced.add(tabId);
  chrome.runtime.sendNativeMessage(NATIVE_MESSAGING_HOST, { url }, (reply) => {
    // Keep the tab on failure, a broken host must not eat links.
    if (chrome.runtime.lastError || !reply || !reply.ok) {
      bounced.delete(tabId);
      console.error(
        "oust:",
        chrome.runtime.lastError?.message ?? JSON.stringify(reply),
      );
      return;
    }
    chrome.tabs.remove(tabId, () => void chrome.runtime.lastError);
  });
}

chrome.webNavigation.onCommitted.addListener((details) => {
  if (details.frameId !== 0) return;
  consider(details.tabId, details.url);
});

chrome.tabs.onRemoved.addListener((tabId) => bounced.delete(tabId));
