"""Consistent response envelope for every Module 03 domain endpoint —
`{"success": true, "data": ...}` for single resources, plus a `meta` block
with page/page_size/total for lists.
"""
from typing import Generic, TypeVar

from fastapi import Query
from pydantic import BaseModel

T = TypeVar("T")


class PageParams(BaseModel):
    page: int = 1
    page_size: int = 20


def page_params(page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100)) -> PageParams:
    return PageParams(page=page, page_size=page_size)


class PageMeta(BaseModel):
    page: int
    page_size: int
    total: int
    total_pages: int

    @classmethod
    def build(cls, page: int, page_size: int, total: int) -> "PageMeta":
        total_pages = max((total + page_size - 1) // page_size, 1)
        return cls(page=page, page_size=page_size, total=total, total_pages=total_pages)


class Envelope(BaseModel, Generic[T]):
    success: bool = True
    data: T


class PaginatedEnvelope(BaseModel, Generic[T]):
    success: bool = True
    data: list[T]
    meta: PageMeta
