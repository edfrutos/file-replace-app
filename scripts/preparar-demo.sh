#!/usr/bin/env bash
# preparar-demo.sh — Crea en el Escritorio los datos de ejemplo para grabar el
# vídeo de App Review y hacer las capturas de la ficha.
#
#   ~/Desktop/Demo/          a.txt y b.txt, para el vídeo
#   ~/Desktop/Capturas-ES/   sitio web de ejemplo, para las capturas en español
#   ~/Desktop/Capturas-EN/   lo mismo en inglés
#   ~/Desktop/Demo-CSV/      pares importables. Va aparte porque Replacer busca
#                            en todos los archivos de la carpeta elegida, y un
#                            CSV dentro de ella saldría entre los resultados.
#
# USO:
#   scripts/preparar-demo.sh           # crea las carpetas; no pisa las que existan
#   scripts/preparar-demo.sh --reset   # además, rehace las creadas por este script
#
# --reset solo borra carpetas con la marca .replacer-demo: una carpeta tuya que
# se llame igual no se toca.
set -euo pipefail

RESET=0
case "${1:-}" in
"") ;;
--reset) RESET=1 ;;
*)
	echo "Uso: $0 [--reset]" >&2
	exit 2
	;;
esac

DESKTOP="${HOME}/Desktop"
MARK=".replacer-demo"

# Devuelve 0 si la carpeta está lista para rellenarla y 1 si hay que dejarla.
prepare() {
	local dir="$1"
	if [[ -e "${dir}" ]]; then
		if ((RESET)) && [[ -f "${dir}/${MARK}" ]]; then
			rm -rf "${dir}"
		elif ((RESET)); then
			echo "Sin tocar (no la creó este script): ${dir}" >&2
			return 1
		else
			echo "Ya existe, se conserva: ${dir} (usa --reset para rehacerla)" >&2
			return 1
		fi
	fi
	mkdir -p "${dir}"
	: >"${dir}/${MARK}"
	echo "Creada: ${dir}"
}

# Sitio de ejemplo: $1 carpeta, $2 tienda antigua, $3 dominio antiguo, $4 título
# de portada, $5 contacto, $6 archivo de contacto, $7 novedades.
site() {
	local dir="$1" shop="$2" domain="$3" title="$4" contact="$5" page="$6" news="$7"
	mkdir -p "${dir}/blog"
	cat >"${dir}/index.html" <<HTML
<!doctype html>
<title>${shop} · ${title}</title>
<link rel="canonical" href="https://${domain}/">
<h1>${shop}</h1>
<a href="https://${domain}/${page}">${contact}</a>
<footer>© 2025 ${shop} · https://${domain}</footer>
HTML
	cat >"${dir}/${page}" <<HTML
<!doctype html>
<title>${contact} · ${shop}</title>
<p>${contact}: hola@${domain}</p>
<footer>© 2025 ${shop}</footer>
HTML
	cat >"${dir}/config.yml" <<YAML
site_name: ${shop}
base_url: https://${domain}
copyright_year: 2025
YAML
	cat >"${dir}/README.md" <<MD
# ${shop}

https://${domain} · © 2025
MD
	cat >"${dir}/blog/novedades.md" <<MD
# ${news}

${shop} 2025: https://${domain}/blog
MD
}

if prepare "${DESKTOP}/Demo"; then
	printf 'hello world, hello\n' >"${DESKTOP}/Demo/a.txt"
	printf 'hello\n' >"${DESKTOP}/Demo/b.txt"
fi

if prepare "${DESKTOP}/Capturas-ES"; then
	site "${DESKTOP}/Capturas-ES" "Tienda Antigua" "tienda-antigua.example" \
		"Inicio" "Contacto" "contacto.html" "Novedades"
fi

if prepare "${DESKTOP}/Capturas-EN"; then
	site "${DESKTOP}/Capturas-EN" "Old Shop" "old-shop.example" \
		"Home" "Contact" "contact.html" "News"
	sed -i.bak 's/hola@/hello@/' "${DESKTOP}/Capturas-EN/contact.html"
	rm -f "${DESKTOP}/Capturas-EN/contact.html.bak"
	mv "${DESKTOP}/Capturas-EN/blog/novedades.md" "${DESKTOP}/Capturas-EN/blog/news.md"
fi

if prepare "${DESKTOP}/Demo-CSV"; then
	cat >"${DESKTOP}/Demo-CSV/pairs.csv" <<CSV
find,replace
hello,goodbye
world,planet
CSV
	cat >"${DESKTOP}/Demo-CSV/pares-capturas.csv" <<CSV
find,replace
tienda-antigua.example,tienda-nueva.example
Tienda Antigua,Tienda Nueva
2025,2026
CSV
	cat >"${DESKTOP}/Demo-CSV/pairs-screenshots.csv" <<CSV
find,replace
old-shop.example,new-shop.example
Old Shop,New Shop
2025,2026
CSV
fi
