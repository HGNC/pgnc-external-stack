import datetime
import sqlalchemy as sa
from typing import Optional, TYPE_CHECKING

from .base import Base
from db.enum_types.basic_status import BasicStatusEnum

if TYPE_CHECKING:
    from db.models.gene import Gene
    from db.models.xref import Xref
    from db.models.user import User


class GeneHasXref(Base):
    __tablename__ = "gene_has_xref"

    gene_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("gene.id"), primary_key=True
    )
    xref_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("xref.id"), primary_key=True
    )
    creator_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("user.id"), nullable=False
    )
    creation_date: sa.orm.Mapped[datetime.datetime] = sa.orm.mapped_column(
        sa.DateTime(), server_default=sa.func.now(), nullable=True
    )
    editor_id: sa.orm.Mapped[Optional[int]] = sa.orm.mapped_column(
        sa.ForeignKey("user.id"), nullable=True
    )
    withdrawn_date: sa.orm.Mapped[Optional[datetime.datetime]] = sa.orm.mapped_column(
        sa.DateTime(), nullable=True
    )
    source: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(10), nullable=False)
    curation_date: sa.orm.Mapped[Optional[datetime.datetime]] = sa.orm.mapped_column(
        sa.DateTime(), nullable=True
    )
    status: sa.orm.Mapped[BasicStatusEnum] = sa.orm.mapped_column(
        sa.Enum(BasicStatusEnum, name="basic_status"), nullable=False
    )

    # Relationships
    ## many to one
    gene: sa.orm.Mapped["Gene"] = sa.orm.relationship(
        "Gene", uselist=False, back_populates="gene_has_xrefs"
    )
    xref: sa.orm.Mapped["Xref"] = sa.orm.relationship(
        "Xref", uselist=False, back_populates="xref_has_genes"
    )
    creator: sa.orm.Mapped["User"] = sa.orm.relationship(
        "User",
        uselist=False,
        back_populates="creator_has_gene_xrefs",
        foreign_keys=[creator_id],
    )
    editor: sa.orm.Mapped["User"] = sa.orm.relationship(
        "User",
        uselist=False,
        back_populates="editor_has_gene_xrefs",
        foreign_keys=[editor_id],
    )

    def __repr__(self):
        return (
            "<GeneHasXref("
            f"gene_id={self.gene_id}, "
            f"xref_id={self.xref_id}, "
            f"creator_id={self.creator_id}, "
            f"creation_date={self.creation_date}, "
            f"editor_id={self.editor_id}, "
            f"withdrawn_date={self.withdrawn_date}, "
            f"source={self.source}, "
            f"curation_date={self.curation_date}, "
            f"status={self.status})>"
        )
