from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from models.gene_has_name import GeneHasName


class Name(Base):
    __tablename__ = "name"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    name: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(45), nullable=False)

    # Relationships
    ## One-to-Many
    name_has_genes: sa.orm.Mapped[Optional[list["GeneHasName"]]] = sa.orm.relationship(
        "GeneHasName", back_populates="name"
    )

    def __repr__(self):
        return "<Name(" f"id={self.id}, " f"name='{self.name}')>"
