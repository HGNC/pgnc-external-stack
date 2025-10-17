from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from db.models.assembly_has_location import AssemblyHasLocation
    from db.models.gene_has_location import GeneHasLocation


class Location(Base):
    __tablename__ = "location"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    name: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(255), nullable=False)
    refseq_accession: sa.orm.Mapped[str] = sa.orm.mapped_column(
        sa.String(255), nullable=True
    )
    genbank_accession: sa.orm.Mapped[str] = sa.orm.mapped_column(
        sa.String(255), nullable=True
    )
    coord_system: sa.orm.Mapped[str] = sa.orm.mapped_column(
        sa.String(20), nullable=True
    )
    type: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(20), nullable=True)

    # Relationships
    ## one-to-many
    location_has_assemblies: sa.orm.Mapped[Optional[list["AssemblyHasLocation"]]] = (
        sa.orm.relationship("AssemblyHasLocation", back_populates="location")
    )
    location_has_genes: sa.orm.Mapped[Optional[list["GeneHasLocation"]]] = (
        sa.orm.relationship("GeneHasLocation", back_populates="location")
    )

    def __repr__(self):
        return (
            f"<Location(id={self.id}, name={self.name}, refseq_accession={self.refseq_accession}, "
            f"genbank_accession={self.genbank_accession}, coord_system={self.coord_system}, type={self.type})>"
        )
