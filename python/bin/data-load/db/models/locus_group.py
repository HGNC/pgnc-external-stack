from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from models.locus_type import LocusType


class LocusGroup(Base):
    __tablename__ = "locus_group"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    name: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(45), nullable=False)

    # Relationships
    ## One-to-Many
    locus_types: sa.orm.Mapped[Optional[list["LocusType"]]] = sa.orm.relationship(
        "LocusType", back_populates="locus_group"
    )

    def __repr__(self):
        return "<LocusGroup(" f"id={self.id}, " f"name='{self.name}')>"
