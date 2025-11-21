(import ./query :as q)
(import spork/json)
(import jurl)
(import jurl/native)

(def commands @["ip" "web" "ssh" "list" "list-details" "details" "set-psk"])
(def default-api-url "https://vpn.myrubicon.tech:8080/get_devices_full")

(defn config-path []
  (def custom (os/getenv "VPN_CONFIG"))
  (if custom
    custom
    (do
      (def xdg (os/getenv "XDG_CONFIG_HOME"))
      (if xdg
        (string xdg "/vpn/config.json")
        (do
          (def home (os/getenv "HOME"))
          (if home
            (string home "/.config/vpn/config.json")
            nil))))))

(defn ensure-dirs [dir]
  (when dir
    (try
      (do
        (os/execute ["mkdir" "-p" dir] :px)
        true)
      ([err] err))))

(defn parent-dir [p]
  (def parts (string/split "/" p))
  (if (> (length parts) 1)
    (let [base (string/join (slice parts 0 (dec (length parts))) "/")]
      (if (string/has-prefix? p "/")
        (if (= base "")
          "/"
          (string "/" base))
        base))
    nil))

(var config-cache nil)

(defn load-config []
  (def primary (config-path))
  (def fallback (string (os/getenv "PWD") "/vpn-config.json"))
  (def path (if (and primary (os/stat primary))
              primary
              (if (os/stat fallback) fallback primary)))
  (when (not path)
    (eprint "Cannot determine config path; set $VPN_CONFIG or HOME/XDG_CONFIG_HOME")
    (os/exit 1))
  (when (not (os/stat path))
    (eprintf "Missing config file at %s\nCreate JSON like: {\"psk\": \"<psk>\", \"api_url\": \"<optional override>\"}\nYou can override the path with $VPN_CONFIG or place vpn-config.json in the current directory." path)
    (os/exit 1))
  (def data (try (json/decode (slurp path))
              ([err]
                (eprintf "Failed to read config %s: %v" path err)
                (os/exit 1))))
  (when (not (data "psk"))
    (eprintf "Config file %s missing \"psk\" key\nExample: {\"psk\": \"<psk>\", \"api_url\": \"<optional override>\"}" path)
    (os/exit 1))
  data)

(defn config []
  (if config-cache
    config-cache
    (do
      (set config-cache (load-config))
      config-cache)))

(defn write-config [psk &opt api-url]
  (def primary (config-path))
  (def fallback (string (os/getenv "PWD") "/vpn-config.json"))
  (def target (or primary fallback))
  (def data @{})
  (defn do-write [path]
    (var ok true)
    (def parent (parent-dir path))
    (def mkres (ensure-dirs parent))
    (when (and mkres (not= mkres true))
      (set ok false)
      (eprintf "Failed to create config directory %s: %v\nSet VPN_CONFIG to a writable path if needed." parent mkres))
    (when (and ok (os/stat path))
      (def old (try (json/decode (slurp path))
                 ([err]
                   (set ok false)
                   (eprintf "Failed to read existing config %s: %v" path err)
                   nil)))
      (when ok (eachp [k v] old (put data k v))))
    (put data "psk" psk)
    (when api-url (put data "api_url" api-url))
    (def buf (buffer/new 0))
    (json/encode data "  " "\n" buf)
    (buffer/push buf "\n")
    (when ok
      (def f (file/open path :w))
      (when (not f)
        (set ok false)
        (eprintf "Failed to open %s for writing; set VPN_CONFIG to a writable path." path))
      (when ok
        (file/write f buf)
        (file/close f)))
    (when ok
      (set config-cache data)
      (printf "Wrote config to %s\n" path))
    ok)
  (cond
    (and primary (do-write primary)) true
    (and fallback (do-write fallback))
    (do
      (printf "Using fallback config path %s. Set VPN_CONFIG to this path to reuse it." fallback)
      true)
    true
    (do
      (eprint "Failed to write config; set VPN_CONFIG to a writable path and retry.")
      (os/exit 1))))

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
    set-psk <psk> [api_url]: Write/update config file
    ``)
  (print msg))

(defn usage []
  (usage-pp)
  (os/exit 64))

(defn resolv
  "Resolve IP"
  [host]
  (q/dns-a host))

(defn fetch-devices
  "Fetch devices from the VPN API using jurl"
  []
  (def cfg (config))
  (def api-url (or (cfg "api_url") default-api-url))
  (def response (jurl/request {:url api-url :headers {"psk" (cfg "psk")}}))
  # valid response?
  (when (not= (response :error) :ok)
    # fuck errors we got body
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
    "set-psk" :set-psk
    _ (do
        (eprint "Error unknown command: " s)
        (usage-pp)
        (os/exit 1))))

(defn handle-ip [host]
  (print host))

(defn find-web-opener []
  (or (os/which "xdg-open")
      (os/which "open")))

(defn handle-web [host]
  (def opener (find-web-opener))
  (when (not opener)
    (eprint "Unable to launch browser; need xdg-open (Linux) or open (macOS) in PATH")
    (os/exit 1))
  (os/execute [opener (string "http://" host)] :pd))

(defn handle-ssh [user host]
  (os/execute
    ["ssh" (string/join @[user "@" host])] :pd))

(defn command? [s]
  (find |(= s $) commands))

(defn normalize-args [args]
  # Support binaries that pass argv[0] as program name or not
  (if (and (> (length args) 1)
           (not (command? (get args 0)))
           (command? (get args 1)))
    (slice args 1)
    args))

(defn main
  [& args]
  (def argv (normalize-args args))
  (when (< (length argv) 1) (usage))
  (def cmd (get argv 0))
  (def cmd-type (handle-cmd cmd))
  (match cmd-type
    :list (handle-list)
    :list-details (handle-list-details)
    :set-psk (do
               (when (< (length argv) 2) (usage))
               (def psk (get argv 1))
               (def api-url (if (> (length argv) 2) (get argv 2) nil))
               (write-config psk api-url))
    :ssh (do
           (when (< (length argv) 3) (usage))
           (def user (get argv 1))
           (def host (resolv (get argv 2)))
           (handle-ssh user host))
    :details (do
               (when (< (length argv) 2) (usage))
               (def hostname (get argv 1))
               (handle-details hostname))
    _ (do
        (when (< (length argv) 2) (usage))
        (def host (resolv (get argv 1)))
        (match cmd-type
          :ip (handle-ip host)
          :web (handle-web host)))))
