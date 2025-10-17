from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from models.xref import Xref


class ExternalResource(Base):
    __tablename__ = "external_resource"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    name: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(45), nullable=False)

    # Relationships
    ## One-to-Many
    xrefs: sa.orm.Mapped[Optional[list["Xref"]]] = sa.orm.relationship(
        "Xref", back_populates="external_resource"
    )

    def __repr__(self):
        return "<ExternalResource(" f"id={self.id}, " f"name='{self.name}')>"
