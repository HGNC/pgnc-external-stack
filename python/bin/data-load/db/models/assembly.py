from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from db.models.assembly_has_location import AssemblyHasLocation
    from db.models.species import Species


class Assembly(Base):
    __tablename__ = "assembly"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    taxon_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("species.taxon_id"), nullable=False
    )
    name: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(255), nullable=False)
    genbank_accession: sa.orm.Mapped[Optional[str]] = sa.orm.mapped_column(
        sa.String(128), nullable=True
    )
    refseq_accession: sa.orm.Mapped[Optional[str]] = sa.orm.mapped_column(
        sa.String(128), nullable=True
    )
    current: sa.orm.Mapped[bool] = sa.orm.mapped_column(sa.Boolean, nullable=False)
    pgnc_default: sa.orm.Mapped[bool] = sa.orm.mapped_column(sa.Boolean, nullable=False)

    # Relationships
    ## one-to-many
    assembly_has_locations: sa.orm.Mapped[Optional[list["AssemblyHasLocation"]]] = (
        sa.orm.relationship("AssemblyHasLocation", back_populates="assembly")
    )

    ## many-to-one
    species: sa.orm.Mapped["Species"] = sa.orm.relationship(
        "Species", uselist=False, back_populates="assemblies"
    )

    def __repr__(self):
        return (
            f"<Assembly(id={self.id}, name={self.name}, refseq_accession={self.refseq_accession}, "
            f"genbank_accession={self.genbank_accession}, taxon_id={self.taxon_id})>"
        )
