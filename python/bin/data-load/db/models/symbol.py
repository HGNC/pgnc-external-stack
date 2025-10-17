from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from db.models.gene_has_symbol import GeneHasSymbol


class Symbol(Base):
    __tablename__ = "symbol"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    symbol: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(45), nullable=False)

    # Relationships
    ## One-to-Many
    symbol_has_genes: sa.orm.Mapped[Optional[list["GeneHasSymbol"]]] = (
        sa.orm.relationship("GeneHasSymbol", back_populates="symbol")
    )

    def __repr__(self):
        return "<Symbol(" f"id={self.id}, " f"symbol='{self.symbol}')"
