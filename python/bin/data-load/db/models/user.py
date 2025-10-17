from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base
from db.models.user_has_role import UserHasRole

if TYPE_CHECKING:
    from db.models.gene import Gene
    from db.models.gene_has_symbol import GeneHasSymbol
    from db.models.gene_has_name import GeneHasName
    from db.models.gene_has_location import GeneHasLocation
    from db.models.gene_has_locus_type import GeneHasLocusType
    from db.models.gene_has_xref import GeneHasXref


class User(Base):
    __tablename__ = "user"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    display_name: sa.orm.Mapped[str] = sa.orm.mapped_column(
        sa.String(128), nullable=False
    )
    first_name: sa.orm.Mapped[str] = sa.orm.mapped_column(
        sa.String(128), nullable=False
    )
    last_name: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(128), nullable=False)
    email: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(128), nullable=False)
    password: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(255), nullable=False)
    current: sa.orm.Mapped[bool] = sa.orm.mapped_column(sa.Boolean, nullable=False)
    connected: sa.orm.Mapped[bool] = sa.orm.mapped_column(sa.Boolean, nullable=False)

    # Relationships
    ## one-to-many
    user_has_roles: sa.orm.Mapped[list["UserHasRole"]] = sa.orm.relationship(
        "UserHasRole", back_populates="user"
    )
    editor_has_genes: sa.orm.Mapped[Optional[list["Gene"]]] = sa.orm.relationship(
        "Gene", back_populates="editor", foreign_keys="[Gene.editor_id]"
    )
    creator_has_genes: sa.orm.Mapped[Optional[list["Gene"]]] = sa.orm.relationship(
        "Gene", back_populates="creator", foreign_keys="[Gene.creator_id]"
    )
    editor_has_gene_symbols: sa.orm.Mapped[Optional[list["GeneHasSymbol"]]] = (
        sa.orm.relationship(
            "GeneHasSymbol",
            back_populates="editor",
            foreign_keys="[GeneHasSymbol.editor_id]",
        )
    )
    creator_has_gene_symbols: sa.orm.Mapped[Optional[list["GeneHasSymbol"]]] = (
        sa.orm.relationship(
            "GeneHasSymbol",
            back_populates="creator",
            foreign_keys="[GeneHasSymbol.creator_id]",
        )
    )
    editor_has_gene_names: sa.orm.Mapped[Optional[list["GeneHasName"]]] = (
        sa.orm.relationship(
            "GeneHasName",
            back_populates="editor",
            foreign_keys="[GeneHasName.editor_id]",
        )
    )
    creator_has_gene_names: sa.orm.Mapped[Optional[list["GeneHasName"]]] = (
        sa.orm.relationship(
            "GeneHasName",
            back_populates="creator",
            foreign_keys="[GeneHasName.creator_id]",
        )
    )
    editor_has_gene_locations: sa.orm.Mapped[Optional[list["GeneHasLocation"]]] = (
        sa.orm.relationship(
            "GeneHasLocation",
            back_populates="editor",
            foreign_keys="[GeneHasLocation.editor_id]",
        )
    )
    creator_has_gene_locations: sa.orm.Mapped[Optional[list["GeneHasLocation"]]] = (
        sa.orm.relationship(
            "GeneHasLocation",
            back_populates="creator",
            foreign_keys="[GeneHasLocation.creator_id]",
        )
    )
    editor_has_gene_locus_types: sa.orm.Mapped[Optional[list["GeneHasLocusType"]]] = (
        sa.orm.relationship(
            "GeneHasLocusType",
            back_populates="editor",
            foreign_keys="[GeneHasLocusType.editor_id]",
        )
    )
    creator_has_gene_locus_types: sa.orm.Mapped[Optional[list["GeneHasLocusType"]]] = (
        sa.orm.relationship(
            "GeneHasLocusType",
            back_populates="creator",
            foreign_keys="[GeneHasLocusType.creator_id]",
        )
    )
    editor_has_gene_xrefs: sa.orm.Mapped[Optional[list["GeneHasXref"]]] = (
        sa.orm.relationship(
            "GeneHasXref",
            back_populates="editor",
            foreign_keys="[GeneHasXref.editor_id]",
        )
    )
    creator_has_gene_xrefs: sa.orm.Mapped[Optional[list["GeneHasXref"]]] = (
        sa.orm.relationship(
            "GeneHasXref",
            back_populates="creator",
            foreign_keys="[GeneHasXref.creator_id]",
        )
    )

    def __repr__(self):
        return (
            f"User(id={self.id}, display_name={self.display_name}, "
            + f"first_name={self.first_name}, last_name={self.last_name}, "
            + f"email={self.email}, current={self.current}, "
            + f"connected={self.connected})"
        )
