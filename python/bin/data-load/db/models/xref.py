from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from models.external_resource import ExternalResource
    from models.gene_has_xref import GeneHasXref


class Xref(Base):
    __tablename__ = "xref"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    display_id: sa.orm.Mapped[str] = sa.orm.mapped_column(
        sa.String(255), nullable=False
    )
    ext_resource_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("external_resource.id"), nullable=False
    )

    # Relationships
    ## One-to-Many
    xref_has_genes: sa.orm.Mapped[Optional[list["GeneHasXref"]]] = sa.orm.relationship(
        "GeneHasXref", back_populates="xref"
    )

    ## Many-to-One
    external_resource: sa.orm.Mapped["ExternalResource"] = sa.orm.relationship(
        "ExternalResource", back_populates="xrefs"
    )

    def __repr__(self):
        return (
            "<Xref("
            f"id={self.id}, "
            f"display_id='{self.display_id}', "
            f"ext_resource_id={self.ext_resource_id})>"
        )
