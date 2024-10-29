import time
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI
from prisma import Prisma, types


prisma = Prisma()


@asynccontextmanager
async def lifespan(_: FastAPI):
    await prisma.connect()
    yield
    await prisma.disconnect()


app = FastAPI(lifespan=lifespan)


@app.get("/test")
async def add_data():
    print("access: /test")
    created = await prisma.post.create(
        types.PostCreateInput(title=f"test {int(time.time())}")
    )
    return {"success": created.model_dump()}


@app.get("/")
async def read_root():
    print("access: /")
    return {"status": prisma.is_connected()}


if __name__ == "__main__":
    uvicorn.run(app="main:app", host="0.0.0.0", port=8000)
