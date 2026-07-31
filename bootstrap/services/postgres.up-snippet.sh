# Postgres port discovery (spliced into up.sh at BOOTSTRAP_SERVICE_PORTS by bootstrap).
  POSTGRES_PORT="$(_get_port postgres 5432)"
  sed -i "s/__POSTGRES_PORT__/${POSTGRES_PORT}/g" "${TMPFILE}"
