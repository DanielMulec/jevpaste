pastes by upstream: {'typesafe-ai': 146, 'any digitalocean': 18, 'no call': 2}
calls by upstream: {'typesafe-ai': 266, 'digitalocean': 19}

## D criteria 1–4 per upstream (passing pastes / pastes)
| group | upstream | 1 positives hit | 1b borderline hit | 2 traps → nothing | 3 whole / paragraph | 4 ask cells ask | 4b asks elsewhere |
|---|---|---|---|---|---|---|---|
| round-1 | typesafe-ai | 64/66 | 16/20 | 10/10 | 11/13 | 4/4 | 0 |
| round-1 | any digitalocean | 7/8 | 4/4 | 2/2 | 3/3 | 0/0 | 0 |
| held-out | typesafe-ai | 17/17 | 0/0 | 4/4 | 6/6 | 5/5 | 0 |
| held-out | any digitalocean | 1/1 | 0/0 | 0/0 | 0/0 | 1/1 | 0 |

## D every miss with its upstreams
| cell | run | group | pasted | calls: upstream per call (step / follow-up) |
|---|---|---|---|---|
| R10_description | 0 | round-1 | `Anna Reisinger⏎Born 14…` | step:typesafe-ai |
| R10_description | 1 | round-1 | `Anna Reisinger⏎Born 14…` | step:typesafe-ai |
| B06_biography | 0 | round-1 | nothing | step:typesafe-ai, follow_up:typesafe-ai |
| B06_biography | 1 | round-1 | nothing | step:typesafe-ai |
| C03_availability | 0 | round-1 | `I can start on 1 Decem…` | step:typesafe-ai, follow_up:typesafe-ai |
| C03_availability | 1 | round-1 | `I can start on 1 Decem…` | step:typesafe-ai, follow_up:typesafe-ai |
| C04_name | 0 | round-1 | `Dear Ms Hofer,⏎⏎I am w…` | step:typesafe-ai, follow_up:digitalocean |

## D cells whose run 0 and run 1 differ (outcome or pasted text)
| cell | group | run 0 | upstreams r0 | run 1 | upstreams r1 |
|---|---|---|---|---|---|
| C04_name | round-1 | `Dear Ms Hofer,⏎⏎I am w…` ✗ | typesafe-ai, digitalocean | `Theo Brandner` | typesafe-ai, typesafe-ai |

cells with differing outcome: 1; cells whose step picks differ at all: 3
