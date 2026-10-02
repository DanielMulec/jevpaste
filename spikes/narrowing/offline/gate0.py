"""Gate 0: Jev's recorded choices + the recorded follow-up rule reproduce every recorded r2b outcome."""
import common as C

pastes = C.load()
ok = bad = 0
for p in pastes:
    if p["cell"] == "N04_too_big":
        continue
    r = C.replay(p, C.jev_rule)
    rec_steps = [s.get("choice_text") if s["choice"] not in C.FIXED else s["choice"] for s in p["steps"]]
    mine = [d for _, d, _ in r["steps"]]
    rec_steps = ["keep" if s == "keep" else s for s in rec_steps]
    same = r["known"] and r["outcome"] == p["outcome"] and r["final"] == p["final"] and mine == rec_steps
    if same:
        ok += 1
    else:
        bad += 1
        print("MISMATCH", p["cell"], p["run"], p["outcome"], C.short(p["final"]), "| replay", r["outcome"],
              C.short(r["final"]), mine[:4], rec_steps[:4])
print("pastes", len(pastes), "replayed identical", ok, "mismatch", bad)
