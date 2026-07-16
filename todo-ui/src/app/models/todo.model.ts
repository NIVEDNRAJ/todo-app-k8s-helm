export interface Todo {
  id: number;
  title: string;
  description: string;
  isCompleted: boolean;
  userId: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateTodoRequest {
  title: string;
  description: string;
}

export interface UpdateTodoRequest {
  title: string;
  description: string;
  isCompleted: boolean;
}

export interface PagedResult<T> {
  items: T[];
  totalCount: number;
  pageNumber: number;
  pageSize: number;
}
