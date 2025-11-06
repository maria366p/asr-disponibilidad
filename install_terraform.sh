# Script de instalación de Terraform usando tfenv.
# ISIS2503 - Arquitectura de Software

if command -v terraform >/dev/null 2>&1; then
    echo "Terraform ya está instalado:"
    terraform --version
    exit 0
fi

git clone https://github.com/tfutils/tfenv.git ~/.tfenv
mkdir -p ~/bin
ln -s ~/.tfenv/bin/* ~/bin/

tfenv install
tfenv use latest

mkdir -p ~/.terraform.d/plugin-cache
echo 'plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"' >> ~/.terraformrc

terraform --version
