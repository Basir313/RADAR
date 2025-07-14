from hdbcli import dbapi
import logging

LOGGER : logging.Logger = None


class SAP_HANA:
    def __init__(self, host, port, user, password):
        self._host = host
        self._port = port
        self._user = user
        self._password = password
        self._connection = None
        self._cursor = None

    def connect(self):
        try:
            self._connection = dbapi.connect(
                address=self._host,
                port=self._port,
                user=self._user,
                password=self._password
            )
            self._cursor = self._connection.cursor()
            LOGGER.info("Connected to SAP HANA")
        except Exception as e:
            LOGGER.warning(f"Error connecting to SAP HANA: {e}")


    def execute(self, query):
        if not self._cursor:
            raise ConnectionError("Not connected to SAP HANA")

        try:
            self._cursor.execute(query)
            columns = [col[0] for col in self._cursor.description]
            rows = self._cursor.fetchall()
            return [dict(zip(columns, row)) for row in rows]
        except dbapi.Error as e:
            LOGGER.error(f"Error executing query: {e}")
            raise