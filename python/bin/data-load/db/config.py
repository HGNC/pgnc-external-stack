import os


class Config:
    db_user = os.environ.get("DB_USER")
    db_password = os.environ.get("DB_PASSWORD")
    db_host = os.environ.get("DB_HOST")
    db_port = os.environ.get("DB_PORT")
    db_name = os.environ.get("DB_NAME")
    DATABASE_URI = (
        f"postgresql://{db_user}:{db_password}@"
        f"{db_host}:{db_port}/{db_name}"  # noqa: E501
    )
