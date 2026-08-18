## Result / 结果

Describe the user-visible outcome and the failure mode addressed.

说明用户可见结果与本次解决的失效模式。

## Preserved invariants / 保持的不变量

- [ ] Bundle ID, Helper label, data path, schema compatibility, and v3 icon are unchanged, or a reviewed migration is included.
- [ ] Helper remains fixed-protocol, local, and free of arbitrary commands/network access.
- [ ] Hardware/storage reads remain read-only.
- [ ] Stress cancellation and thermal protections remain intact.
- [ ] Network access remains explicit, disclosed, cancellable, and key-free on the client.

## Validation / 验证

List exact commands, real-device checks, visual checks, and any untested macOS or hardware conditions. A successful compile alone is not release proof.

列出实际命令、真机检查、视觉检查，以及尚未覆盖的 macOS/硬件条件。仅编译成功不能作为发行证据。

## Privacy / 隐私

- [ ] No DMG, archive, user history, credential, diagnostic bundle, private screenshot, full local path, or device/network identifier is included.
