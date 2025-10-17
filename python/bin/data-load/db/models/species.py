import sqlalchemy as sa
from typing import TYPE_CHECKING

from .base import Base

if TYPE_CHECKING:
    from db.models.gene import Gene
    from db.models.assembly import Assembly


class Species(Base):
    __tablename__ = "species"

    taxon_id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    common_name: sa.orm.Mapped[str] = sa.orm.mapped_column(
        sa.String(255), nullable=False
    )
    scientific_name: sa.orm.Mapped[str] = sa.orm.mapped_column(
        sa.String(255), nullable=False
    )

    # Relationships
    ## one-to-many
    genes: sa.orm.Mapped[list["Gene"]] = sa.orm.relationship(
        "Gene", back_populates="species"
    )
    assemblies: sa.orm.Mapped[list["Assembly"]] = sa.orm.relationship(
        "Assembly", back_populates="species"
    )

    def __repr__(self):
        return (
            f"<Species("
            f"taxon_id={self.taxon_id}, "
            f"common_name='{self.common_name}', "
            f"scientific_name='{self.scientific_name}')>"
        )
