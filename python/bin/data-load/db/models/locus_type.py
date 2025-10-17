from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from models.locus_group import LocusGroup
    from models.gene_has_locus_type import GeneHasLocusType


class LocusType(Base):
    __tablename__ = "locus_type"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    name: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(45), nullable=False)
    locus_group_id: sa.orm.Mapped[Optional[int]] = sa.orm.mapped_column(
        sa.ForeignKey("locus_group.id"), nullable=True
    )

    # Relationships
    ## One-to-Many
    locus_type_has_genes: sa.orm.Mapped[Optional[list["GeneHasLocusType"]]] = (
        sa.orm.relationship("GeneHasLocusType", back_populates="locus_type")
    )

    ## Many-to-One
    locus_group: sa.orm.Mapped["LocusGroup"] = sa.orm.relationship(
        "LocusGroup", back_populates="locus_types"
    )

    def __repr__(self):
        return (
            "<LocusType("
            f"id={self.id}, "
            f"name='{self.name}', "
            f"locus_group_id={self.locus_group_id})>"
        )
