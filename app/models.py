from pydantic import BaseModel


class ProviderRequest(BaseModel):
    name: str
    provider: str
    client_id: str
    client_secret: str