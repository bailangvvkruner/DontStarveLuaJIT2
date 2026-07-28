.PHONY: build_linux stress_test

build_linux:
	bash tools/build_linux_compatible.sh

stress_test:
	python3 tests/stress_test_mod/run_stress_test.py
