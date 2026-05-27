(declare-project
  :name "vpn-util"
  :description "VPN utility for hostname resolution and connection"
  :dependencies ["spork"
                 {:repo "https://github.com/cosmictoast/jurl.git"}])

(declare-executable
  :name "vpn"
  :entry "vpn.janet"
  :deps ["./query.janet"])
