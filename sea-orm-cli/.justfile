set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

# 这里需要本地有.env文件，并且记录的文件内容包括GITHUB_TOKNE
set dotenv-load
# ===============
# ===Variables===
PROJ_NAME := ""
CARGO_PROJ_OUPUT_BIN := "sea-orm-cli"
PY_SHEBANG := if os() == "windows"{"python"} else {"/usr/bin/env python"}
BINARY_INSTALL_PATH := if os() == "macos"{"/usr/local/bin"} else {"D://dtool"}
PLAT_FORMS := "x86_64-pc-windows-gnu,x86_64-unknown-linux-musl,aarch64-apple-darwin"
# ===Variables===
# ===============


# =============
# ===Private===
[private]
default:
    just --list



__cargo_build method plat="":
    #!{{PY_SHEBANG}}
    import sys 
    import os 
    exec_cmd = "cargo build %s %s" % (len("{{plat}}") > 0 and "--target %s" % "{{plat}}" or "", '{{method}}' == "release" and "--release" or "")
    print(exec_cmd)
    ret = os.system(exec_cmd)
    if ret != 0:
        print("cargo build [%s] failed!" % "{{plat}}")  
        sys.exit(2)
    print("cargo build [%s] success!" % "{{plat}}")
    
__cargo_cross_build method:
    #!/usr/bin/env bash
    for plat in $(echo "{{PLAT_FORMS}}" | tr "," "\n"); do
        just __cargo_build {{method}} $plat
    done

__install_bin method:
    #!{{PY_SHEBANG}}
    import os
    import sys
    import platform
    import shutil

    bin_f = sys.platform == "win32" and "{{CARGO_PROJ_OUPUT_BIN}}.exe" or "{{CARGO_PROJ_OUPUT_BIN}}"
    mv_f = os.path.join(r'{{justfile_directory()}}', 'target', '{{method}}' == "release" and "release" or "debug", bin_f)
    print(mv_f)
    if not os.path.isfile(mv_f):
        print("cargo build failed!")
    shutil.copyfile(mv_f, "{{BINARY_INSTALL_PATH}}/{{CARGO_PROJ_OUPUT_BIN}}")
    os.system("sudo chmod +x {{BINARY_INSTALL_PATH}}/{{CARGO_PROJ_OUPUT_BIN}}")

# ===Private===
# =============

install_loc method="release":
    just __cargo_build {{method}}
    sudo just __install_bin {{method}}

# 生成文档
gen_doc:
    git-cliff  -o ./CHANGE_LOG.md



#发布binary页面到sea-ocm-cli
__pub_release env="hs" pub_type="dry-nexus" :
    cd {{justfile_directory()}}/envs/{{env}} && hfrog -p {{justfile_directory()}}/out publish --alias-method {{pub_type}}


# 生成输出的路径
__gen_outdir tar pub_target="nexus":
    #!{{PY_SHEBANG}}
    import os
    import sys
    import shutil

    root_dir = os.path.join(r'{{justfile_directory()}}', "out")
    if os.path.isdir(root_dir):
        shutil.rmtree(root_dir)
    

    PLAT_FORMS = "{{PLAT_FORMS}}".split(",")
    for plat in PLAT_FORMS:
        bin_from_f = os.path.join(r'{{justfile_directory()}}','target',  plat, "release",  plat.count("windows") > 0 and "{{tar}}.exe" or "{{tar}}")
        os.makedirs(os.path.join(root_dir, plat))
        shutil.copyfile(bin_from_f, os.path.join(root_dir, plat, plat.count("windows") > 0 and "{{tar}}.exe" or "{{tar}}"))
    yml_from_f = os.path.join('{{justfile_directory()}}', "hfrog.yml")
    script_from_f = os.path.join('{{justfile_directory()}}', 'scripts', '{{pub_target}}', 'install.sh')

    yml_to_f = os.path.join(root_dir, "hfrog.yml")
    shutil.copyfile(yml_from_f, yml_to_f)    
    shutil.copyfile(script_from_f, os.path.join(root_dir, "install.sh"))

# 发布hfrog到hfrog ;3
# pub_host: Union["hs"|"life-jt"]
# pub_target: Union["nexus"|"s3"]
build_and_pub pub_host="hs" pub_target="nexus":
    just __cargo_cross_build release
    just __gen_outdir {{CARGO_PROJ_OUPUT_BIN}} {{pub_target}}
    just __pub_release {{pub_host}}
