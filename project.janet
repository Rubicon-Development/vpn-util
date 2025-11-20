(declare-project
  :name "vpn-util"
  :description "VPN utility for hostname resolution and connection"
  :dependencies ["spork"
                 {:repo "https://github.com/cosmictoast/jurl.git"
                  :tag "v1.4.3"}])

(declare-executable
  :name "vpn"
  :entry "vpn.janet"
  :deps ["./query.janet"])
