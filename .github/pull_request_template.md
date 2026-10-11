## Summary

-

## Checks

- [ ] `scripts/check.sh <pkg>` passes for each package this changes
- [ ] `scripts/native-check.sh <pkg>` passes when the package has `effs/*.c`
- [ ] A change to `<pkg>.bend` or `effs/` raises `VERSION`
- [ ] A breaking change bumps the second version number and has a line in `CHANGELOG.md`
