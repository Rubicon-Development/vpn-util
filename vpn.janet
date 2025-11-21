(import ./query :as q)
(import spork/json)
(import jurl)
(import jurl/native)

(defn usage-pp []
  (def msg ``
    Usage: vpn [COMMAND] [ARGS...]
    Commands:
    ip <hostname>: Show the ip
    web <hostname>: Open local webpage in browser
    ssh <user> <hostname>: Start an ssh connection
    list: Show a list of device names
    list-details: Show all available information for each device
    details <hostname>: Show detailed information for a specific device
    ``)
  (print msg))

(defn usage []
  (usage-pp)
  (os/exit 64))

(defn resolv
  "Resolve IP"
  [host]
  (q/dns-a host))

(def api-url "https://vpn.myrubicon.tech:8080/get_devices_full")
(def api-psk "bp9ZdSDz4my/X4g/jFah2GIFWXYRxoJGGiVS8ro/5ag=")

(defn fetch-devices
  "Fetch devices from the VPN API using jurl"
  []
  (def response (jurl/request {:url api-url :headers {"psk" api-psk}}))
  # Check if we got a valid response
  (when (not= (response :error) :ok)
    # Ignore SSL errors if we have a body
    (when (not (response :body))
      (eprintf "Error fetching devices: %q" (native/strerror (response :error)))
      (os/exit 1)))
  (json/decode (response :body)))

(defn handle-list
  "Display a list of device names"
  []
  (def devices (fetch-devices))
  (each device devices
    (print (device "hostname"))))

(defn handle-list-details
  "Display detailed information for all devices"
  []
  (def devices (fetch-devices))
  (each device devices
    (print "Device: " (device "hostname"))
    (print "  Type: " (device "dev_type"))
    (print "  IP: " (device "ip"))
    (print "  Last Seen: " (device "last_seen"))
    (print "  Firmware: " (device "fw_version"))
    (print "  Public Key: " (device "public_key"))
    (print)))

(defn handle-details
  "Display detailed information for a specific device"
  [hostname]
  (def devices (fetch-devices))
  (def device (find |(= ($ "hostname") hostname) devices))
  (if device
    (do
      (print "Device: " (device "hostname"))
      (print "  Type: " (device "dev_type"))
      (print "  IP: " (device "ip"))
      (print "  Last Seen: " (device "last_seen"))
      (print "  Firmware: " (device "fw_version"))
      (print "  Public Key: " (device "public_key")))
    (do
      (eprint "Device not found: " hostname)
      (os/exit 1))))

(defn handle-cmd [s]
  (match s
    "ip" :ip
     "web" :web
     "ssh" :ssh
     "list" :list
     "list-details" :list-details
     "details" :details
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

(defn handle-ssh [user host]
  (os/execute
   ["ssh" (string/join @[user "@" host])] :pd))

(defn main
  [& args]
  (when (< (length args) 2) (usage))
  (def cmd (get args 1))
  (def cmd-type (handle-cmd cmd))
  (match cmd-type
    :list (handle-list)
    :list-details (handle-list-details)
    :ssh (do
          (when (< (length args) 4) (usage))
          (def user (get args 2))
          (def host (resolv (get args 3)))
          (handle-ssh user host))
    :details (do
              (when (< (length args) 3) (usage))
              (def hostname (get args 2))
              (handle-details hostname))
    _ (do
        (when (< (length args) 3) (usage))
        (def host (resolv (get args 2)))
        (match cmd-type
          :ip (handle-ip host)
          :web (handle-web host)))))
