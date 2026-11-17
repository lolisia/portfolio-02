extends RefCounted
class_name MobileProfile

## Explicit mobile budget; desktop visuals keep the original path.
static func enabled() -> bool:
	return OS.has_feature("mobile") or "--mobile-profile" in OS.get_cmdline_user_args()
