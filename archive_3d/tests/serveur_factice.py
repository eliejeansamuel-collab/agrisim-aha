"""Serveur factice imitant le FORMAT des deux API (Open-Meteo altitude, NASA POWER climatologie).
Sert à tester le téléchargement, le cache et le mode hors ligne sans accès Internet.
Les VALEURS sont inventées : ce ne sont pas des données réelles."""
import json, math
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

MOIS = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
def serie(v): d = dict(zip(MOIS, v)); d["ANN"] = sum(v)/12; return d

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        u = urlparse(self.path); q = parse_qs(u.query)
        if u.path.endswith("/elevation"):
            la = [float(x) for x in q["latitude"][0].split(",")]
            lo = [float(x) for x in q["longitude"][0].split(",")]
            if len(la) > 100: return self.rep(400, {"error": True, "reason": "too many"})
            la0, lo0 = 7.41, -7.55
            e = [round(352 + 1700*(a-la0) + 550*(o-lo0) + 3*math.sin((a-la0)*2500)*math.cos((o-lo0)*2300), 1) for a, o in zip(la, lo)]
            return self.rep(200, {"elevation": e})
        if "climatology" in u.path:
            p = {"PRECTOTCORR": serie([0.5,1.9,3.8,5.1,5.4,6.9,6.7,8.5,10.2,5.6,1.8,0.6]),
                 "T2M_MAX": serie([33,34,33,32,31,29,28,28,29,30,31,32]),
                 "T2M_MIN": serie([19,21,22,22,22,21,21,21,21,21,21,19]),
                 "RH2M": serie([55,62,72,78,81,84,86,87,86,83,76,62]),
                 "WS2M": serie([1.4,1.6,1.7,1.6,1.5,1.6,1.8,1.8,1.5,1.3,1.2,1.3]),
                 "ALLSKY_SFC_SW_DWN": serie([19.5,20.8,20.6,19.9,18.6,16.4,14.6,14.2,16.1,18.0,18.6,18.4])}
            return self.rep(200, {"type": "Feature", "geometry": {"type": "Point", "coordinates": [float(q["longitude"][0]), float(q["latitude"][0]), 340]}, "properties": {"parameter": p}})
        self.rep(404, {})
    def rep(self, code, obj):
        b = json.dumps(obj).encode(); self.send_response(code)
        self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

HTTPServer(("127.0.0.1", 8765), H).serve_forever()
