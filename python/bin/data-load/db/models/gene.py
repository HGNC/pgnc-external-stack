import datetime
import sqlalchemy as sa
from typing import Optional, TYPE_CHECKING

from db.enum_types.gene_status import GeneStatusEnum
from .base import Base

if TYPE_CHECKING:
    from db.models.species import Species
    from db.models.user import User
    from db.models.gene_has_symbol import GeneHasSymbol
    from db.models.gene_has_name import GeneHasName
    from db.models.gene_has_location import GeneHasLocation
    from db.models.gene_has_locus_type import GeneHasLocusType
    from db.models.gene_has_xref import GeneHasXref


class Gene(Base):
    __tablename__ = "gene"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    taxon_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("species.taxon_id"), nullable=False
    )
    creator_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("user.id"), nullable=False
    )
    creation_date: sa.orm.Mapped[datetime.datetime] = sa.orm.mapped_column(
        sa.DateTime(), server_default=sa.func.now(), nullable=False
    )
    editor_id: sa.orm.Mapped[Optional[int]] = sa.orm.mapped_column(
        sa.ForeignKey("user.id"), nullable=True
    )
    mod_date: sa.orm.Mapped[datetime.datetime] = sa.orm.mapped_column(
        sa.DateTime(), nullable=True
    )
    withdrawn_date: sa.orm.Mapped[Optional[datetime.datetime]] = sa.orm.mapped_column(
        sa.DateTime(), nullable=True
    )
    status: sa.orm.Mapped[GeneStatusEnum] = sa.orm.mapped_column(
        sa.Enum(GeneStatusEnum, name="gene_status"), nullable=False
    )
    primary_id: sa.orm.Mapped[Optional[str]] = sa.orm.mapped_column(
        sa.String(16), nullable=True
    )
    primary_id_source: sa.orm.Mapped[Optional[str]] = sa.orm.mapped_column(
        sa.String(50), nullable=True
    )

    # one to many relationships
    gene_has_symbols: sa.orm.Mapped[Optional[list["GeneHasSymbol"]]] = (
        sa.orm.relationship("GeneHasSymbol", back_populates="gene")
    )
    gene_has_names: sa.orm.Mapped[Optional[list["GeneHasName"]]] = sa.orm.relationship(
        "GeneHasName", back_populates="gene"
    )
    gene_has_locations: sa.orm.Mapped[Optional[list["GeneHasLocation"]]] = (
        sa.orm.relationship("GeneHasLocation", back_populates="gene")
    )
    gene_has_locus_types: sa.orm.Mapped[Optional[list["GeneHasLocusType"]]] = (
        sa.orm.relationship("GeneHasLocusType", back_populates="gene")
    )
    gene_has_xrefs: sa.orm.Mapped[Optional[list["GeneHasXref"]]] = sa.orm.relationship(
        "GeneHasXref", back_populates="gene"
    )

    # Many to one relationships
    species: sa.orm.Mapped["Species"] = sa.orm.relationship(
        "Species", uselist=False, back_populates="genes"
    )
    creator: sa.orm.Mapped["User"] = sa.orm.relationship(
        "User",
        uselist=False,
        back_populates="creator_has_genes",
        foreign_keys=[creator_id],
    )
    editor: sa.orm.Mapped["User"] = sa.orm.relationship(
        "User",
        uselist=False,
        back_populates="editor_has_genes",
        foreign_keys=[editor_id],
    )

    def __repr__(self):
        return (
            f"<Gene(id={self.id}, taxon_id={self.taxon_id}, status={self.status})>"
            + f" creation_date={self.creation_date}, creator_id={self.creator_id}, editor_id={self.editor_id}"
            + f" mod_date={self.mod_date}, withdrawn_date={self.withdrawn_date}"
            + f" primary_id={self.primary_id}, primary_id_source={self.primary_id_source}"
        )
