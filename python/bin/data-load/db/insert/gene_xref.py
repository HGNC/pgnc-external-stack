from typing import Literal

from db.models.xref import Xref
from db.models.gene_has_xref import GeneHasXref


class GeneXref:
    def __init__(
        self,
        session,
        display_id: str,
        ext_res_id: int,
        gene_id: int,
        creator_id: int,
        source: str,
        status: Literal["public", "private"],
    ):
        xref_i: Xref | None = (
            session.query(Xref)
            .where(Xref.display_id == display_id, Xref.ext_resource_id == ext_res_id)
            .one_or_none()
        )
        if xref_i is None:
            xref_i = self._create_xref(session, display_id, ext_res_id)
        elif ext_res_id != 4:
            raise ValueError(
                f"Xref with display_id '{display_id}' and ext_resource_id '{ext_res_id}' already exists"
            )
        gene_has_xref_i = self._create_gene_has_xref(
            session, gene_id, xref_i.id, creator_id, source, status
        )
        self.xref_id = xref_i.id
        self.gene_id = gene_id
        self.creator_id = creator_id
        self.source = source
        self.status = status
        self.creation_date = gene_has_xref_i.creation_date

    def _create_xref(self, session, display_id: str, ext_res_id: int):
        xref_i = Xref(display_id=display_id, ext_resource_id=ext_res_id)
        session.add(xref_i)
        session.flush()
        session.refresh(xref_i)
        return xref_i

    def _create_gene_has_xref(
        self,
        session,
        gene_id: int,
        xref_id: int,
        creator_id: int,
        source: str,
        status: Literal["public", "private"],
    ):
        gene_has_xref_i = GeneHasXref(
            gene_id=gene_id,
            xref_id=xref_id,
            creator_id=creator_id,
            source=source,
            status=status,
        )
        session.add(gene_has_xref_i)
        session.flush()
        session.refresh(gene_has_xref_i)
        return gene_has_xref_i

    def __repr__(self):
        return (
            f"<GeneXref(xref_id={self.xref_id}, "
            f"gene_id={self.gene_id}, creator_id={self.creator_id}, "
            f"source='{self.source}', status='{self.status}', "
            f"creation_date={self.creation_date})>"
        )
