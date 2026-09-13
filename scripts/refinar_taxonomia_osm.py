"""Aplica de forma idempotente las decisiones de taxonomia al CSV OSM."""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = REPOSITORY_ROOT / "supabase" / "seed" / "importacion_osm_tulcan.csv"

# Mapeos aplicables a cualquier objeto con la etiqueta, tenga o no nombre.
TAG_MAPPINGS = {
    "telecommunication": ("tecnologia-electronica", "telefonia-movil"),
    "beverages": ("comida-bebidas", "bares-bebidas"),
    "confectionery": ("comida-bebidas", "heladerias-postres"),
    "department_store": (
        "tiendas-supermercados",
        "centros-comerciales-grandes-almacenes",
    ),
    "mall": (
        "tiendas-supermercados",
        "centros-comerciales-grandes-almacenes",
    ),
    "toys": ("educacion-papeleria", "jugueterias"),
    "appliance": ("tecnologia-electronica", "electronica"),
    "general": ("tiendas-supermercados", "tiendas-barrio"),
    "florist": ("tiendas-supermercados", "floristerias"),
    "internet_cafe": ("tecnologia-electronica", "computacion"),
    "metal_construction": ("hogar-construccion", "materiales-construccion"),
    "shoemaker": ("servicios-oficios", "reparaciones"),
}

# Decisiones que dependen de la identidad/nombre del establecimiento.
NAMED_MAPPINGS = {
    ("seafood", "Cevicheria Cuatro Ases"): (
        "comida-bebidas",
        "restaurantes",
    ),
    ("car", "Authesa"): ("automotriz-movilidad", "venta-vehiculos"),
    ("yes", "SuperExpress"): ("tiendas-supermercados", "minimarkets"),
}

MANUAL_REVIEW = {
    ("outdoor", "EMELNORTE"),
    ("butcher", "Centro de Faenamiento de Tulcán"),
}

MANUAL_REVIEW_REASONS = {
    ("outdoor", "EMELNORTE"): (
        "Etiqueta outdoor incompatible con el nombre; requiere revisión manual."
    ),
    ("butcher", "Centro de Faenamiento de Tulcán"): (
        "Centro de faenamiento; requiere revisión manual antes de clasificar."
    ),
}

CATEGORY_NAMES = {
    "comida-bebidas": "Comida y bebidas",
    "tiendas-supermercados": "Tiendas y supermercados",
    "tecnologia-electronica": "Tecnología y electrónica",
    "automotriz-movilidad": "Automotriz y movilidad",
    "hogar-construccion": "Hogar y construcción",
    "educacion-papeleria": "Educación y papelería",
    "servicios-oficios": "Servicios y oficios",
}

SUBCATEGORY_NAMES = {
    "restaurantes": "Restaurantes",
    "bares-bebidas": "Bares y bebidas",
    "heladerias-postres": "Heladerías y postres",
    "centros-comerciales-grandes-almacenes": (
        "Centros comerciales y grandes almacenes"
    ),
    "minimarkets": "Minimarkets",
    "tiendas-barrio": "Tiendas de barrio",
    "jugueterias": "Jugueterías",
    "electronica": "Electrónica",
    "telefonia-movil": "Telefonía móvil",
    "computacion": "Computación",
    "venta-vehiculos": "Venta de vehículos",
    "floristerias": "Floristerías",
    "materiales-construccion": "Materiales de construcción",
    "reparaciones": "Reparaciones",
}


def main() -> None:
    with CSV_PATH.open(encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source)
        fieldnames = reader.fieldnames
        rows = list(reader)

    if not fieldnames or len(rows) != 306:
        raise ValueError("El CSV debe contener sus cabeceras y exactamente 306 filas")

    for row in rows:
        tag = row["etiqueta_osm"].strip()
        name = row["nombre_original"].strip()

        mapping = TAG_MAPPINGS.get(tag) or NAMED_MAPPINGS.get((tag, name))

        # shop=yes con nombre se acepta como tienda de barrio, salvo
        # SuperExpress, que tiene una decision especifica de minimarket.
        if tag == "yes" and name:
            mapping = NAMED_MAPPINGS.get(
                (tag, name),
                ("tiendas-supermercados", "tiendas-barrio"),
            )

        if mapping:
            row["categoria_slug_destino"], row["subcategoria_slug_destino"] = mapping
            row["categoria_oficial"] = CATEGORY_NAMES[mapping[0]]
            row["subcategoria_nombre"] = SUBCATEGORY_NAMES[mapping[1]]

        if not name:
            row["estado_importacion"] = "observado"
            if mapping or not row["motivo_observacion"].startswith("Sin nombre"):
                row["motivo_observacion"] = "Sin nombre"
        elif (tag, name) in MANUAL_REVIEW:
            row["estado_importacion"] = "observado"
            row["motivo_observacion"] = MANUAL_REVIEW_REASONS[(tag, name)]
        elif mapping or row["estado_importacion"] == "valido":
            row["estado_importacion"] = "valido"
            row["motivo_observacion"] = ""

        row["publicable_propuesto"] = "false"

    identities = {
        (row["lote_id"], row["osm_type"], row["osm_id"])
        for row in rows
    }
    states = Counter(row["estado_importacion"] for row in rows)
    unnamed = [row for row in rows if not row["nombre_original"].strip()]
    named_observed = [
        row
        for row in rows
        if row["nombre_original"].strip()
        and row["estado_importacion"] == "observado"
    ]

    if len(identities) != 306:
        raise ValueError("El refinamiento produjo identidades OSM duplicadas")
    if states != Counter({"valido": 254, "observado": 52}):
        raise ValueError(f"Conteos inesperados después del refinamiento: {states}")
    if len(unnamed) != 50 or any(
        row["estado_importacion"] != "observado" for row in unnamed
    ):
        raise ValueError("Los 50 registros sin nombre deben permanecer observados")
    if {
        (row["etiqueta_osm"], row["nombre_original"])
        for row in named_observed
    } != MANUAL_REVIEW:
        raise ValueError("Los registros de revisión manual no son los esperados")

    temporary_path = CSV_PATH.with_suffix(".csv.tmp")
    with temporary_path.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    temporary_path.replace(CSV_PATH)

    print("Refinamiento completado: 254 válidos, 52 observados, 0 descartados")


if __name__ == "__main__":
    main()
