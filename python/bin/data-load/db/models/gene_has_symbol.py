import datetime
import sqlalchemy as sa
from typing import Optional, TYPE_CHECKING

from .base import Base
from db.enum_types.nomenclature import NomenclatureEnum
from db.enum_types.basic_status import BasicStatusEnum

if TYPE_CHECKING:
    from db.models.gene import Gene
    from db.models.symbol import Symbol
    from db.models.user import User


class GeneHasSymbol(Base):
    __tablename__ = "gene_has_symbol"

    gene_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("gene.id"), primary_key=True
    )
    symbol_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.ForeignKey("symbol.id"), primary_key=True
    )
    type: sa.orm.Mapped[NomenclatureEnum] = sa.orm.mapped_column(
        sa.Enum(NomenclatureEnum, name="nomenclature_type"), nullable=False
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
    mod_date: sa.orm.Mapped[Optional[datetime.datetime]] = sa.orm.mapped_column(
        sa.DateTime(), nullable=True
    )
    withdrawn_date: sa.orm.Mapped[Optional[datetime.datetime]] = sa.orm.mapped_column(
        sa.DateTime(), nullable=True
    )
    status: sa.orm.Mapped[BasicStatusEnum] = sa.orm.mapped_column(
        sa.Enum(BasicStatusEnum, name="basic_status"), nullable=False
    )

    # Relationships
    ## many to one
    gene: sa.orm.Mapped["Gene"] = sa.orm.relationship(
        "Gene", uselist=False, back_populates="gene_has_symbols"
    )
    symbol: sa.orm.Mapped["Symbol"] = sa.orm.relationship(
        "Symbol", uselist=False, back_populates="symbol_has_genes"
    )
    creator: sa.orm.Mapped["User"] = sa.orm.relationship(
        "User",
        uselist=False,
        back_populates="creator_has_gene_symbols",
        foreign_keys=[creator_id],
    )
    editor: sa.orm.Mapped["User"] = sa.orm.relationship(
        "User",
        uselist=False,
        back_populates="editor_has_gene_symbols",
        foreign_keys=[editor_id],
    )

    def __repr__(self):
        return (
            "GeneHasSymbol("
            f"gene={self.gene}, "
            f"symbol={self.symbol}, "
            f"type={self.type}, "
            f"creator={self.creator}, "
            f"creation_date={self.creation_date}, "
            f"editor={self.editor}, "
            f"mod_date={self.mod_date}, "
            f"withdrawn_date={self.withdrawn_date}, "
            f"status={self.status})"
        )
