extends RefCounted

func run() -> int:
	if 1 + 1 != 2:
		push_error("sanity math failed")
		return 1
	return 0
