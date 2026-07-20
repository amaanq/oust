#!/usr/bin/env nu
# Native messaging host that hands escaped web app links to xdg-open.
const max_message_bytes = 1048576

def read-exact [count: int] {
   ^head -c $count | into binary
}

def send-reply [reply: record] {
   let body = $reply | to json --raw | into binary
   let header = $body | bytes length | into binary | bytes at 0..3
   bytes build $header $body | print --raw
}

# The browser launches the host directly, so the parent is the browser process
# and its argv carries the web app wrapper's --oust-keep flag.
def keep-list [] {
   let stat = open --raw /proc/self/stat
   let ppid = $stat | split row ') ' | last | split row ' ' | get 1
   let flag = open --raw $'/proc/($ppid)/cmdline'
   | split row (char nul)
   | where { str starts-with '--oust-keep=' }
   | get 0?
   if $flag == null { return null }
   $flag | str replace '--oust-keep=' '' | split row ',' | where { is-not-empty }
}

def main [] {
   loop {
      let header = try { read-exact 4 } catch { 0x[] }
      if ($header | bytes length) < 4 { break }
      let length = $header | into int --endian little
      if $length > $max_message_bytes { break }
      let message = try { read-exact $length | decode | from json } catch { {} }
      if ($message.config? == true) {
         send-reply {keep: (try { keep-list } catch { null })}
         continue
      }
      let url = $message.url?
      let ok = try { ($url | str starts-with 'http://') or ($url | str starts-with 'https://') } catch { false }
      if $ok {
         # A detached setsid child, or xdg-open itself, must never inherit the protocol stdout.
         ^setsid --fork xdg-open $url out+err> /dev/null
      }
      send-reply {ok: $ok}
   }
}
