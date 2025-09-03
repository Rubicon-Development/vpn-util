(import ./query :as q)

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
  (q/dns-a host))

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

(defn handle-web [host]
  (def cmd (match (os/which)
             :windows "start"
             :linux "xdg-open"
             (do
               (eprint "OS not supported")
               (os/exit 1))))
  (os/execute [cmd (string/join @["http://" host])] :pd))

(defn handle-ssh [host]
  (os/execute
    ["ssh" (string/join @["apex@" host])] :pd))

(defn main
  [& args]
  (when (< (length args) 3) (usage))
  (def cmd (get args 1))
  (def host (resolv (get args 2)))
  (match (handle-cmd cmd)
    :ip (handle-ip host)
    :web (handle-web host)
    :ssh (handle-ssh host)))
