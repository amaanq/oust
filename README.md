# oust

Chromium app windows (`--app=...`) never hand links to the system. Click an
external link in a web app wrapper and it opens in a bare browser window
inside the app's isolated profile, with none of your real cookies or
extensions. oust throws those links out the window and gives them
to `xdg-open`, so your actual URL handler decides where they go.

An MV3 extension watches for top level navigations that land in a plain
browser window of the profile, a window an app profile has no business
showing. It hands the URL to a native messaging host and closes the orphan
tab. App and popup windows are left alone so OAuth flows keep working. The
host is a nushell script that lets only http and https through to
`xdg-open`.

## Usage

Enable the host on NixOS

```nix
programs.oust.enable = true;
```

then force-install the extension through chromium policy, which also gets it
past an `ExtensionInstallBlocklist` of `*` that rejects unpacked extensions

```nix
programs.chromium.extensions = [ "${oust.extensionId};${oust.updateUrl}" ];
```

and start each web app with the hosts it keeps

```nix
--oust-keep=cinny.example.com,accounts.google.com
```

`--oust-keep` lists the hosts that stay inside the profile, subdomains
included. Add your identity provider if an app signs in through a full
window redirect. A profile started without the flag, like your main
browser, leaves every link alone.

The host manifest lands in `/etc/chromium/native-messaging-hosts`, which
chromium and its forks read for every profile, including ones started with
`--user-data-dir`. Point `x-scheme-handler/http` at something smarter than
a browser and a link clicked in one web app can open in another.
