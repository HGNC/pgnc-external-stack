import sqlalchemy as sa
from typing import TYPE_CHECKING

from .base import Base

if TYPE_CHECKING:
    from db.models.assembly import Assembly
    from db.models.location import Location


class AssemblyHasLocation(Base):
    __tablename__ = "assembly_has_location"

    assembly_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("assembly.id"), primary_key=True
    )
    location_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("location.id"), primary_key=True
    )

    # Relationships
    ## many-to-one
    assembly: sa.orm.Mapped["Assembly"] = sa.orm.relationship(
        "Assembly", back_populates="assembly_has_locations"
    )
    location: sa.orm.Mapped["Location"] = sa.orm.relationship(
        "Location", back_populates="location_has_assemblies"
    )

    def __repr__(self):
        return f"<AssemblyHasLocation(assembly_id={self.assembly_id}, location_id={self.location_id})>"
