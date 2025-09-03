#!/usr/bin/env janet

(defn usage-pp []
  (def msg ``
    Usage: vpn [ip|web|ssh] [Hostname]
    Commands:
    ip: Show the ip
    web: Open loval webpage in browser
    ssh: start and ssh connection
    ``)
  (print msg))

(defn usage []
  (usage-pp)
  (os/exit 64))

(defn resolv
  "Resolve IP"
  [host]
  (def f (file/temp))
  (os/execute ["dig" "-p" "5354" "@10.12.0.1" "-4" "+short" host] :p {:out f})
  (file/seek f :set 0)
  (def out (file/read f :all))
  (file/close f)
  (string/trim out))

(defn handle-cmd [s]
  (match s
    "ip" :ip
    "web" :web
    "ssh" :ssh
    _ (do
        (eprint "Error unknown command: " s)
        (usage-pp)
        (os/exit 1))))

(defn handle-ip [host]
  (print host))

(defn find-path [name]
  (if (string/find name "/")
    (when (os/stat name) name)
    (let [paths (string/split ":" (os/getenv "PATH"))]
      (some (fn [d]
              (let [p (string d "/" name)]
                (when (os/stat p) p)))
            paths))))

(defn handle-web [host]
  (os/execute [(find-path "xdg-open") (string/join @["http://" host])]))

(defn handle-ssh [host]
  (os/execute
    [(find-path "ssh") (string/join @["apex@" host])]))

(defn main
  [& args]
  (when (< (length args) 3) (usage))
  (def cmd (get args 1))
  (def host (resolv (get args 2)))
  (match (handle-cmd cmd)
    :ip (handle-ip host)
    :web (handle-web host)
    :ssh (handle-ssh host)))
