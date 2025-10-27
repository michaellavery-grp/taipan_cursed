# Taipan Cursed Version Comparison

## Quick Stats
- **v0.1.1**: 963 lines, simple combat
- **v1.0.0**: 2,363 lines, complex combat + warehouses

## Key Differences

### Combat System
**v0.1.1**: Simple auto-resolve (guns vs pirates count)
**v1.0.0**: Interactive combat loop with user choices

### Warehouse System
**v0.1.1**: Single warehouse (player.warehouse)
**v1.0.0**: Multi-port warehouses (7 ports × 10,000 capacity each)

### New Features in v1.0.0
- Bank system (deposit/withdraw at Hong Kong)
- Ship damage tracking
- Port risk levels (theft/spoilage)
- Save/load game (JSON)
- ASCII map art (7 different maps)
- Date tracking with interest calculation
- Li Yuen special pirate encounters

## To Compare Versions
```bash
# See all changes
diff -u Taipan_2020_v0.1.1.pl Taipan_2020_v1.0.0.pl > changes.diff

# See just file structure
diff -y --suppress-common-lines Taipan_2020_v0.1.1.pl Taipan_2020_v1.0.0.pl | less

# Compare specific sections
diff -u <(sed -n '115,126p' Taipan_2020_v0.1.1.pl) <(sed -n '1292,1441p' Taipan_2020_v1.0.0.pl)
```

## GitHub Branch Comparison
If you have these as separate branches:
```
https://github.com/michaellavery-grp/taipan_cursed/compare/v0.1.1...v1.0.0
```
