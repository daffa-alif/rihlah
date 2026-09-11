import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  Body,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { FirebaseAuthGuard, RolesGuard, Roles } from '@rihlah/firebase';

@Controller('users')
@UseGuards(FirebaseAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  /** Create or get a user profile (idempotent on firebaseUid). */
  @Post()
  async create(@Body() dto: CreateUserDto) {
    return this.usersService.create(dto);
  }

  /** Get current user's own profile (uid extracted from auth token). */
  @Get('me')
  async getMe(@Param('uid') uid: string) {
    // The request has `req.user.uid` from FirebaseAuthGuard
    return this.usersService.findById(uid);
  }

  /** Get a user by ID. */
  @Get(':id')
  async getById(@Param('id') id: string) {
    return this.usersService.findById(id);
  }

  /** Update user profile. */
  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateUserDto) {
    return this.usersService.update(id, dto);
  }

  /** Admin: list all users. */
  @Get()
  @Roles('admin')
  @UseGuards(RolesGuard)
  async findAll(
    @Query('role') role?: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.usersService.findAll({ role, limit, offset });
  }

  /** Admin: set user role. */
  @Patch(':id/role')
  @Roles('admin')
  @UseGuards(RolesGuard)
  async setRole(@Param('id') id: string, @Body('role') role: string) {
    return this.usersService.setRole(id, role);
  }

  /** Admin: suspend or activate a user. */
  @Patch(':id/status')
  @Roles('admin')
  @UseGuards(RolesGuard)
  async setStatus(
    @Param('id') id: string,
    @Body('status') status: string,
  ) {
    return this.usersService.setAccountStatus(id, status);
  }
}
