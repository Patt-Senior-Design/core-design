set modules {csr}

foreach module $modules {
  read_sverilog -r -define SYNTHESIS behavioral/$module.v
  set_top $module

  read_sverilog -i -define SYNTHESIS [glob rtl/src/$module.v rtl/rtldefs.vh rtl/lib/*]
  set_top $module

  match

  verify

  remove_container -all
}

exit
