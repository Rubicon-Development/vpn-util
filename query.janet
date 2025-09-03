(defn u16be [bs i] (+ (blshift (get bs i) 8) (get bs (+ i 1))))

(defn push16be [buf n]
  (buffer/push-byte buf (band (brshift n 8) 0xFF) (band n 0xFF)))

(defn make-query [hostname]
  (def b (buffer/new 64))
  (push16be b 0x1234)      # TXID
  (push16be b 0x0100)      # flags: standard query, RD=1
  (push16be b 1)           # QDCOUNT
  (push16be b 0)           # ANCOUNT, NSCOUNT, ARCOUNT
  (push16be b 0)
  (push16be b 0)
  
  # Encode hostname
  (if (string/find "." hostname)
    (each label (string/split hostname ".")
      (buffer/push-byte b (length label))
      (buffer/push-string b label))
    (do
      (buffer/push-byte b (length hostname))
      (buffer/push-string b hostname)))
  
  (buffer/push-byte b 0)   # end of name
  (push16be b 1)           # QTYPE=A
  (push16be b 1)           # QCLASS=IN
  b)

(defn parse-a-records [resp]
  (def ips @[])
  # Scan for A record pattern: type=1, class=1, rdlen=4
  (var i 0)
  (while (< (+ i 12) (length resp))
    (when (and (= (get resp i) 0x00) (= (get resp (+ i 1)) 0x01)      # type A
               (= (get resp (+ i 2)) 0x00) (= (get resp (+ i 3)) 0x01)  # class IN
               (= (get resp (+ i 8)) 0x00) (= (get resp (+ i 9)) 0x04)) # rdlen=4
      (def ip-start (+ i 10))
      (when (<= (+ ip-start 4) (length resp))
        (array/push ips (string (get resp ip-start) "."
                                (get resp (+ ip-start 1)) "."
                                (get resp (+ ip-start 2)) "."
                                (get resp (+ ip-start 3))))))
    (set i (+ i 1)))
  ips)

(defn dns-a [hostname &opt server port]
  (default server "10.12.0.1")
  (default port 5354)
  (def sock (net/connect server port :datagram))
  (net/write sock (make-query hostname))
  (def resp (net/read sock 512))
  (when (dyn 'net/close) (net/close sock))
  (def ips (parse-a-records resp))
  (if (> (length ips) 0)
    (get ips 0)
    nil))

# Example:
# (pp (dns-a "mcsv2f1"))
