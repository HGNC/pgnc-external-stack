from typing import Literal

from db.models.symbol import Symbol
from db.models.gene_has_symbol import GeneHasSymbol


class GeneSymbol:
    def __init__(
        self,
        session,
        symbol: str,
        gene_id: int,
        creator_id: int,
        type: Literal["approved", "alias", "previous"],
        status: Literal["public", "private"],
    ):
        symbol_i = self._create_symbol(session, symbol)
        gene_has_symbol_i = self._create_gene_has_symbol(
            session, gene_id, symbol_i.id, type, creator_id, status
        )
        self.symbol_id = symbol_i.id
        self.gene_id = gene_id
        self.creator_id = creator_id
        self.type = type
        self.status = status
        self.creation_date = gene_has_symbol_i.creation_date

    def _create_symbol(self, session, symbol: str):
        symbol_i = Symbol(symbol=symbol)
        session.add(symbol_i)
        session.flush()
        session.refresh(symbol_i)
        return symbol_i

    def _create_gene_has_symbol(
        self,
        session,
        gene_id: int,
        symbol_id: int,
        type: Literal["approved", "alias", "previous"],
        creator_id: int,
        status: Literal["public", "private"],
    ):
        gene_has_symbol_i = GeneHasSymbol(
            gene_id=gene_id,
            symbol_id=symbol_id,
            type=type,
            creator_id=creator_id,
            status=status,
        )
        session.add(gene_has_symbol_i)
        session.flush()
        session.refresh(gene_has_symbol_i)
        return gene_has_symbol_i

    def __repr__(self):
        return (
            f"<GeneSymbol(symbol_id={self.symbol_id}, "
            f"gene_id={self.gene_id}, creator_id={self.creator_id}, "
            f"type='{self.type}', status='{self.status}', "
            f"creation_date={self.creation_date})>"
        )
